require 'java'
require 'thread'

class Time
  def round(seconds = 60)
    Time.at((self.to_f / seconds).round * seconds)
  end

  def floor(seconds = 60)
    Time.at((self.to_f / seconds).floor * seconds)
  end
end

class Machine < Base::Machine
  include TorqueBox::Messaging::Backgroundable

  attr_accessor :external_vm_id,
    :external_host_id,
    :name,
    :stats,
    :description,
    :account_id

  CURLBIN = ENV['CURL'] || "curl"
  KB = 1024
  MB = 1024**2
  GB = 1024**3
  TB = 1024**4

  # Used to cache Host CPU hz to avoid making repetitive VMWare SOAP calls
  @@hz_cache = {}

  def initialize(args={})
    self.stats = args["stats"] if args["stats"].present?
    super
  end

  def self.create(inode, _account_id, _hypervisor_data_store_uuid, _media_store_location, _ovf_file_path, _virtual_machine_uuid, _network_maps, _disk_maps)
    begin
      logger.info("machine.create")
      adaptor = inode.vmware_api_adaptor
      datastore = inode.datastores.select { |ds| ds["moref_id"] == _hypervisor_data_store_uuid }.first
      datastore = inode.datastores.first if datastore.blank?
      logger.info("deploying to: #{datastore.inspect}")
      raise "Unable to find datastore!" if datastore.blank?

      host = datastore["host_mor"]
      resource_pool = host.get_parent.get_resource_pool

      ovf_manager = adaptor.connection.get_ovf_manager

      # create account folder for virtual machine; if it doesn't exist
      vm_account_folder = nil
      vm_account_folder_name = "Account#{_account_id.to_s}"
      root_folder = adaptor.root_folder.get_child_entity.first.get_vm_folder

      # figure out if something already exists with the name
      vm_account_folder = root_folder.get_child_entity.find { |child_entity| child_entity.name == vm_account_folder_name }
      raise "An item with the name of the folder already exists but it's not a folder!" if vm_account_folder.present? && vm_account_folder.get_class.to_s != "com.vmware.vim25.mo.Folder"

      logger.info "create vm account folder unless it exists: #{!vm_account_folder.nil?}"
      vm_account_folder = root_folder.create_folder(vm_account_folder_name) if vm_account_folder.nil?

      # check if the vm already exists
      virtual_machine = vm_account_folder.get_child_entity.find { |child_entity| child_entity.name == _virtual_machine_uuid }
      raise "Virtual machine already exists: #{virtual_machine.inspect}" if virtual_machine.present?

      begin
        # get ovf xml
        source_ovf_file_path = File.join(_media_store_location, _ovf_file_path)
        ovf_xml = IO.read(source_ovf_file_path)

        # parse ovf
        parse_params = Vim::OvfParseDescriptorParams.new()
        parse_params.set_locale("US")
        parse_params.set_deployment_option("")
        ovf_parse_result = ovf_manager.parseDescriptor(ovf_xml, parse_params)

        # TODO: disk mappings for thin/thick
        # _disk_maps.each do |disk_mapping|

        # end

        # TODO: resize memory

        # create import spec
        machine_specs = Vim::OvfCreateImportSpecParams.new()
        machine_specs.set_host_system(host.get_mor)
        machine_specs.set_locale("US")
        machine_specs.set_entity_name(_virtual_machine_uuid)
        machine_specs.set_deployment_option("")
        machine_specs.set_property_mapping(nil)

        # nic mapping
        _network_maps.each do |network_mapping|
          nic_name = network_mapping["nic_name"]
          logger.info("looking for nic: #{nic_name}")

          network_name = network_mapping["network_name"]
          logger.info("looking for network_name: #{network_name}")

          ovf_nic = ovf_parse_result.get_network.find { |nic| nic.get_name == nic_name }
          inode_network = adaptor.networks.find { |inode_network| inode_network["name"] == network_name }

          if ovf_nic.present? && inode_network.present?
            network_mapping = Vim::OvfNetworkMapping.new()
            network_mapping.set_name(ovf_nic.get_name) # nic name
            network_mapping.set_network(inode_network["mor"].get_mor) # inode network
            machine_specs.set_network_mapping([network_mapping])
          end
        end

        # import
        ovf_import_result = ovf_manager.create_import_spec(ovf_xml, resource_pool, datastore["mor"], machine_specs)

        # TODO: handle errors and warnings
        ovf_import_result.get_error.each do |error|
          logger.error(error.get_localized_message)
          raise error.get_localized_message
        end if ovf_import_result.get_error.present?

        ovf_import_result.get_warning.each do |warning|
          logger.warn(warning.get_localized_message)
        end if ovf_import_result.get_warning.present?

        # lease management
        http_nfc_lease = resource_pool.import_vapp(ovf_import_result.get_import_spec, vm_account_folder, host)
        begin
          sleep(0.01) while !["ready", "error"].include?(http_nfc_lease.get_state.to_s)
          if http_nfc_lease.get_state.to_s == "ready"
            hnli = http_nfc_lease.get_info
            logger.info("state: #{http_nfc_lease.get_state.to_s}")
            # printHttpNfcLeaseInfo(hnli)
            deviceUrls = hnli.get_device_url

            deviceUrls.each do |device_url|
              progress = 5.0
              ovf_import_result.get_file_item.each do |ovf_file_item|
                device_key = device_url.get_import_key
                if device_key == ovf_file_item.get_device_id
                  keep_alive_thread = Thread.new do
                    while true
                      http_nfc_lease.http_nfc_lease_progress(progress.to_i)
                      logger.info("renewed lease, waiting 60 seconds")
                      sleep(60)
                    end
                  end

                  # file upload(s)
                  method = ovf_file_item.create ? "PUT" : "POST"
                  logger.info "url: #{device_url.url}"
                  device_post_url = device_url.url.gsub("*", host.config.network.vnic[0].spec.ip.ipAddress)
                  logger.info "clean url: #{device_post_url}"
                  logger.info "ovf file path: #{ovf_file_item.get_path}"
                  device_filename = "#{ovf_file_item.get_path}"

                  source_full_path = File.join(_media_store_location, device_filename)

                  upload_command = "#{CURLBIN} --data-binary '@#{source_full_path}' -Ss -X #{method} --insecure -H 'Content-Type: application/x-vnd.vmware-streamVmdk' '#{URI::escape(device_post_url)}'"
                  logger.info(upload_command)
                  Kernel.system("#{upload_command}")

                  logger.info("killing lease keep-alive thread")
                  keep_alive_thread.kill
                  keep_alive_thread.join

                  progress += (90.0 / ovf_file_item.get_size)
                  logger.info("updating progress: #{progress.to_s}")
                  http_nfc_lease.http_nfc_lease_progress(progress.to_i)
                end
              end
            end

            return Machine.new(adaptor.find_vm_by_mor(hnli.get_entity, true))
          end
        ensure
          logger.info("removing lease")
          http_nfc_lease.httpNfcLeaseProgress(100)
          http_nfc_lease.httpNfcLeaseComplete()
        end
      ensure
      end
    rescue Vim::InvalidRequest, Vim::SystemError => e
      logger.error("#{e.class} - Message: \"#{e.get_localized_message.to_s}\"")
    ensure
      inode.close_connection
    end
  end

  # def self.printHttpNfcLeaseInfo(_info)
  #   logger.info("================ HttpNfcLeaseInfo ================")
  #   _info.getDeviceUrl.each do |durl|
  #     logger.info("Device URL Import Key: " + durl.getImportKey())
  #     logger.info("Device URL Key: " + durl.getKey())
  #     logger.info("Device URL : " + durl.getUrl())
  #     logger.info("Updated device URL: " + durl.getUrl())
  #   end
  #   logger.info("Lease Timeout: " + _info.getLeaseTimeout.to_s)
  #   logger.info("Total Disk capacity: " + _info.getTotalDiskCapacityInKB.to_s)
  #   logger.info("==================================================")
  # end

  def self.all(inode)
    begin
      inode.vmware_api_adaptor.virtual_machines
    rescue Vim::InvalidLogin => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Forbidden, "Invalid Login"
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable, e.to_s
    ensure
      inode.close_connection
    end
  end

  def self.all_with_readings(inode, _interval = 300, _since = 10.minutes.ago.utc, _until = 5.minutes.ago.utc)
    begin
      # Retrieve all machines and virtual machine references
      start_time = _since.floor(5.minutes).utc
      end_time = _until.round(5.minutes).utc
      adaptor = inode.vmware_api_adaptor
      machines = adaptor.readings(adaptor.virtual_machines, start_time, end_time)
      machines
    rescue InvalidLogin => e
      raise Exceptions::Forbidden, "Invalid Login"
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable, e.to_s
    ensure
      inode.close_connection
    end
  end

  def self.find_by_uuid(inode, uuid)
    begin
      vm = inode.vmware_api_adaptor.find_vm_by_uuid(uuid)

      unless vm.nil?
        Machine.new(vm)
      else
        raise Exceptions::NotFound
      end
    rescue InvalidLogin => e
      raise Exceptions::Forbidden, "Invalid Login"
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable, e.to_s
    ensure
      inode.close_connection
    end
  end


  def self.find_by_uuid_with_readings(inode, uuid, _interval = 300, _since = 10.minutes.ago.utc, _until = 5.minutes.ago.utc)
    begin
      start_time = _since.floor(5.minutes).utc
      end_time = _until.round(5.minutes).utc
      adaptor = inode.vmware_api_adaptor
      vm = adaptor.readings(adaptor.find_vm_by_uuid(uuid), start_time, end_time)

      unless vm.nil?
        Machine.new(vm)
      else
        raise Exceptions::NotFound
      end
    rescue InvalidLogin => e
      raise Exceptions::Forbidden, "Invalid Login"
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable, e.to_s
    ensure
      inode.close_connection
    end
  end

  def readings(_interval = 300, _since = 10.minutes.ago.utc, _until = 5.minutes.ago.utc)
    begin
      result = []
      # timestamps.keys.each do |timestamp|
      if !@stats.nil?
        @stats.keys.each do | timestamp |
          metrics = @stats[timestamp]
          # Note: cpu.usage.average unit of measure is hundreths of a percent so 1023 is really 10.23% or .1023
          # you could assert that metric["cpu.usage.average"].to_f /10000) * @cpu_speed * @cpu_count = metrics["cpu.usagemhz.average"]
          cpu_usage = metrics["cpu.usage.average"].nil? ? 0 : metrics["cpu.usage.average"] == -1 ? 0 : (metrics["cpu.usage.average"].to_f / 10000)
          memory_bytes = metrics["mem.consumed.average"].nil? ? 0 : metrics["mem.consumed.average"] == -1 ? 0 : metrics["mem.consumed.average"] * 1024
          result << MachineReading.new({
                                         :interval     => _interval,
                                         :cpu_usage    => cpu_usage,
                                         :memory_bytes => memory_bytes,
                                         :date_time    => timestamp
                                       })

        end
      end

      #       logger.debug("CPU Metric Usage="+(metric_readings[cpu_metric_usage][i].to_f / (100**2)).to_s)
      #       logger.debug("cpu.usagemhz.average="+metric_readings[cpu_metric_usagemhz][i].to_s)

      result
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable, e.to_s
    end
  end


  def self.start(inode, _virtual_machine_uuid)
    logger.info("machine.start")
    machine = Machine.new(inode.vmware_api_adaptor.start(_virtual_machine_uuid))
  end

  def self.stop(inode, _virtual_machine_uuid)
    logger.info("machine.stop")
    machine = Machine.new(inode.vmware_api_adaptor.stop(_virtual_machine_uuid))
  end

  def self.restart(inode, _virtual_machine_uuid)
    logger.info("machine.restart")
    machine = Machine.new(inode.vmware_api_adaptor.restart(_virtual_machine_uuid))
  end

  def self.force_restart(inode, _virtual_machine_uuid)
    logger.info("machine.start")
    machine = Machine.new(inode.vmware_api_adaptor.force_restart(_virtual_machine_uuid))
  end

  def self.force_stop(inode, _virtual_machine_uuid)
    logger.info("machine.stop")
    machine = Machine.new(inode.vmware_api_adaptor.force_stop(_virtual_machine_uuid))
  end

  def self.delete(inode, _virtual_machine_uuid)
   logger.info("machine.delete")
   inode.vmware_api_adaptor.destroy(_virtual_machine_uuid)
  end

  # def update_nic(vd)
  #   if(vd instanceof VirtualEthernetCard && (vd.getDeviceInfo().getLabel().equalsIgnoreCase("Network Adapter 1"))){
  #     logger.info("Virtual Ethernet Card: " + vd.getDeviceInfo().getLabel());
  #     # VirtualEthernetCard card = (VirtualEthernetCard) vd;
  #     VirtualDeviceBackingInfo properties = vd.getBacking();
  #     VirtualEthernetCardNetworkBackingInfo nicBacking = (VirtualEthernetCardNetworkBackingInfo) properties;
  #     logger.info("Current NIC backing device name: " + nicBacking.getDeviceName());
  #     # VirtualEthernetCardNetworkBackingInfo newBI = new VirtualEthernetCardNetworkBackingInfo();
  #     # newBI.network = networkMOR;
  #     # newBI.deviceName = newNetworkName;
  #     # vd.backing = newBI;
  #     # VirtualDeviceConfigSpec spec = new VirtualDeviceConfigSpec();
  #     # spec.device = vd;
  #     # spec.operation = VirtualDeviceConfigSpecOperation.edit;
  #     # spec.operationSpecified = true;
  #     VirtualMachineConfigSpec config = new VirtualMachineConfigSpec();
  #     config.deviceChange = new VirtualDeviceConfigSpec { spec };
  #     vm.reconfigVM_Task(config);
  #   }
  # end

  def nics=(_nics)
    @nics = _nics.map {|nic| MachineNic.new(nic)}
    if @nics.nil?.eql?(false)
      @nics.each do |nic|
        nic.stats = stats
      end
    end
  end

  def disks=(_disks)
    @disks = _disks.map {|disk| MachineDisk.new(disk)}
    if @disks.nil?.eql?(false)
      @disks.each do |disk|
        disk.stats = stats
      end
    end
  end

  private
  def self.log_available_methods(_object, _regex=nil, _execute_it=false)
    logger.info("_object class type: #{_object.get_class}")

    methods = _object.methods
    methods = methods.grep(_regex) if _regex.present?

    methods.each do |method|
      logger.info "Method: #{method}"
      logger.info "*** Result: #{_object.send(method)}" if _execute_it
    end
  end

  # Helper Method for converting machine power states.
  def self.convert_power_state(tools_status, power_status)
    logger.info('machine.convert_power_state')

    begin
      status = "#{tools_status}|#{power_status}"

      case status
      when "toolsOk|poweredOn"
        "started"
      when "toolsOld|poweredOn"
        "started"
      when "toolsNotInstalled|poweredOn"
        "started"
      when "toolsNotRunning|poweredOff"
        "stopped"
      when "toolsOld|poweredOff"
        "stopped"
      when "toolsNotInstalled|poweredOff"
        "stopped"
      when "toolsNotRunning|poweredOn"
        "started"
      else
        "Unknown"
      end
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable, e.message
    end
  end
end
