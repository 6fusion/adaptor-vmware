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
                :description

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

  def create(inode, _account_id, _media_store_path, _ovf_file_name, _virtual_machine_uuid)
    begin
      logger.info("machine.create")
      adaptor = inode.vmware_api_adaptor
      host = adaptor.hosts.first
      resource_pool = host[:mor].get_parent.get_resource_pool
      datastore = host[:mor].get_datastores.first
      ovf_manager = adaptor.connection.get_ovf_manager

      # mount
      source_file_path = ""
      begin
        # mount source file path
        account_folder = "Account#{_account_id.to_s}/"
        logger.info "full mount path: #{_media_store_path}"
        source_file_path = mount(_media_store_path)

        # get ovf xml
        ovf_file_name = _ovf_file_name
        source_ovf_file_path = File.join(source_file_path, ovf_file_name)
        ovf_xml = IO.read(source_ovf_file_path)

        # parse ovf
        parse_params = Vim::OvfParseDescriptorParams.new()
        parse_params.set_locale("US")
        parse_params.set_deployment_option("")
        ovf_parse_result = ovf_manager.parseDescriptor(ovf_xml, parse_params)

        # create import spec
        machine_specs = Vim::OvfCreateImportSpecParams.new()
        machine_specs.set_host_system(host[:mor].get_mor)
        machine_specs.set_locale("US")
        machine_specs.set_entity_name(_virtual_machine_uuid)
        machine_specs.set_deployment_option("")
        machine_specs.set_property_mapping(nil)

        # nic mapping
        ovf_parse_result.get_network.each do |nic|
          # nic.methods.grep(/get\_/).each do |cmd|
          #   logger.info "#{cmd} : #{nic.send(cmd)}"
          # end
          network_mapping = Vim::OvfNetworkMapping.new()
          network = adaptor.networks.find { |n| n["name"] == "VINET02" } # network mapping
          network_mapping.set_name(nic.get_name) # nic/network card name
          network_mapping.set_network(network["mor"].get_mor)
          machine_specs.set_network_mapping([network_mapping])
        end

        # import
        ovf_import_result = ovf_manager.create_import_spec(ovf_xml, resource_pool, datastore, machine_specs)

        # TODO: handle errors and warnings
        ovf_import_result.get_error.each do |error|
          logger.error(error.get_localized_message)
        end if ovf_import_result.get_error.present?

        ovf_import_result.get_warning.each do |warning|
          logger.warn(warning.get_localized_message)
        end if ovf_import_result.get_warning.present?

        # create account folder for virtual machine; if it doesn't exist
        # TODO: figure out how to do this
        vm_account_folder = adaptor.virtual_machines.first["mor"].get_parent #.create_folder(account_folder)

        # lease management
        http_nfc_lease = resource_pool.import_vapp(ovf_import_result.get_import_spec, vm_account_folder, host[:mor])
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
                  device_post_url = device_url.url.gsub("*", host[:mor].config.network.vnic[0].spec.ip.ipAddress)
                  logger.info "clean url: #{device_post_url}"
                  logger.info "ovf file path: #{ovf_file_item.get_path}"
                  device_filename = "#{ovf_file_item.get_path}"
                  # /Users/alexgandy/Desktop/dsl/
                  source_full_path = File.join(source_file_path, device_filename)

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

            return adaptor.find_vm_by_mor(hnli.get_entity)
          end
        ensure
          logger.info("removing lease")
          http_nfc_lease.httpNfcLeaseProgress(100)
          http_nfc_lease.httpNfcLeaseComplete()
        end

      # clean up
      ensure
        unmount(source_file_path) if source_file_path.present?
      end
    rescue Vim::InvalidRequest,
      Vim::SystemError => e
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
      unless vm.nil? || vm.first.nil?
        Machine.new(vm.first)
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
      unless vm.nil? || vm.first.nil?
        Machine.new(vm.first)
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
                                           :date_time    => timestamp }
            )

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


  def start(inode)
    logger.info("machine.start")
    machine = inode.vmware_api_adaptor.start(uuid)
  end

  def stop(inode)
   logger.info("machine.stop")
   machine = inode.vmware_api_adaptor.stop(uuid)
  end

  def restart(inode)
   logger.info("machine.restart")
   machine = inode.vmware_api_adaptor.restart(uuid)
  end

  def force_restart(inode)
   logger.info("machine.start")
   machine = inode.vmware_api_adaptor.force_restart(uuid)
  end

  def force_stop(inode)
   logger.info("machine.stop")
   machine = inode.vmware_api_adaptor.force_stop(uuid)
  end

  # def delete(inode)
  #  logger.info("machine.delete")
  #  machine = inode.vmware_api_adaptor.destroy(uuid)
  # end

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

  def mount(_mount_path, _local_mount_path="/mnt/upload_location")
      logger.info("mounting #{_mount_path} -> #{_local_mount_path}")
      mount_cmd = "sudo mount -t nfs #{_mount_path} #{_local_mount_path}" # -o sync 2>&1
      logger.info mount_cmd
      Kernel.system("#{mount_cmd}")
      logger.info("mounted: #{_local_mount_path}")
      return _local_mount_path
  end

  def unmount(_local_mount_path)
    logger.info("unmounting #{_local_mount_path}")
    Kernel.system("sudo umount #{_local_mount_path}")
  end
end
