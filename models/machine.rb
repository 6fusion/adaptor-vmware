require 'java'
# Dir['lib/java/**/*.jar'].each do |jar|
#   $CLASSPATH << jar
#   require jar
# end
# $CLASSPATH << "#{PADRINO_ROOT}/lib/java"
# java_import "com.sixfusion.VMwareAdaptor"
# java_import "com.vmware.vim25.InvalidLogin"


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

  KB = 1024
  MB = 1024**2
  GB = 1024**3
  TB = 1024**4

  # Used to cache Host CPU hz to avoid making repetitive VMWare SOAP calls
  @@hz_cache = {}

  def initialize(args)
    self.stats = args["stats"] if args["stats"]
    super
  end

  def self.from_ovf(xml)
    ovf = Ovfparse::OVF.from_xml(xml)
    ovf_disks = ovf.disks
    ovf.virtual_systems.map do |vm|
      machine = Machine.new({
        virtual_name:   vm.name,
        description:    vm.description,
        cpu_count:      vm.cpus,
        maximum_memory: vm.memory,
        disks:          vm.disks,
        #nics:           vm.network_cards,
        optical_drives: vm.optical_drives,
        other_configs:  vm.other_configurations
      })
      # map vm disk to a file defined in the ovf
      machine.disks.each do |disk|
        ovf_disk = ovf_disks.find { |d| d["name"] == File.basename(disk.HostResource) }
        disk.location = ovf_disk['location']
        disk.size = ovf_disk['size']
      end

      machine
    end
  end

  def create(inode, options={ })
    begin
      logger.info("machine.create")
      adaptor = inode.vmware_api_adaptor
      host = adaptor.hosts.first
      machine_specs = Vim::OvfCreateImportSpecParams.new()
      machine_specs.set_host_system(host[:mor].get_mor)
      machine_specs.set_locale("US")
      machine_specs.set_entity_name(@virtual_name)
      machine_specs.set_deployment_option("")
      network_mapping = Vim::OvfNetworkMapping.new()
      network = adaptor.networks.find { |n| n["name"] == "VINET02" } # network mapping
      network_mapping.set_name("VM Network") # nic/network card name
      network_mapping.set_network(network["mor"].get_mor)
      machine_specs.set_network_mapping([network_mapping])
      machine_specs.set_property_mapping(nil)

      rp = host[:mor].get_parent.get_resource_pool
      datastore = host[:mor].get_datastores.first
      ovf_manager = adaptor.connection.get_ovf_manager
      ovf_import_result = ovf_manager.create_import_spec(options["xml"].to_java(:string), rp, datastore, machine_specs)

      http_nfc_lease = rp.import_vapp(ovf_import_result.get_import_spec, adaptor.virtual_machines.first["mor"].get_parent, host[:mor])
      begin
        sleep(0.01) while !["ready", "error"].include?(http_nfc_lease.get_state.to_s)
        if http_nfc_lease.get_state.to_s == "ready"
          logger.info("HttpNfcLeaseState: ready")
          hnli = http_nfc_lease.get_info
          printHttpNfcLeaseInfo(hnli)

          # leaseUpdater = new LeaseProgressUpdater(httpNfcLease, 5000);
          # leaseUpdater.start();

          deviceUrls = hnli.get_device_url

          # long bytesAlreadyWritten = 0;
          deviceUrls.each do |deviceUrl|
            ovf_import_result.getFileItem.each do |ovfFileItem|
              device_key = deviceUrl.getImportKey
              if device_key == ovfFileItem.getDeviceId()
                logger.info("Import key==OvfFileItem device id: " + device_key)
                # String absoluteFile = new File(ovfLocal).getParent() + File.separator + ovfFileItem.getPath();
                # String urlToPost = deviceUrl.getUrl().replace("*", hostip);
                # uploadVmdkFile(ovfFileItem.isCreate(), absoluteFile, urlToPost, bytesAlreadyWritten, totalBytes);
                # bytesAlreadyWritten += ovfFileItem.getSize();
                # logger.info("Completed uploading the VMDK file:" + absoluteFile)
              end
            end
          end
          # leaseUpdater.interrupt();

          adaptor.find_vm_by_mor(hnli.get_entity)
        end
      ensure
        logger.info("removing lease")
        http_nfc_lease.httpNfcLeaseProgress(100)
        http_nfc_lease.httpNfcLeaseComplete()
      end
    rescue Vim::InvalidRequest,
      Vim::SystemError => e
      logger.error("#{e.class} - Message: \"#{e.get_localized_message.to_s}\"")
    ensure
      inode.close_connection
    end
  end

  def printHttpNfcLeaseInfo(_info)
    logger.info("================ HttpNfcLeaseInfo ================")
    _info.getDeviceUrl.each do |durl|
      logger.info("Device URL Import Key: " + durl.getImportKey())
      logger.info("Device URL Key: " + durl.getKey())
      logger.info("Device URL : " + durl.getUrl())
      logger.info("Updated device URL: " + durl.getUrl())
    end
    logger.info("Lease Timeout: " + _info.getLeaseTimeout.to_s)
    logger.info("Total Disk capacity: " + _info.getTotalDiskCapacityInKB.to_s)
    logger.info("==================================================")
  end

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
  #   logger.info("machine.delete")

  #   begin
  #     vm.Destroy_Task.wait_for_completion
  #     @power_state = "deleted"

  #   rescue RbVmomi::Fault => e
  #     logger.error(e.message)
  #     raise Exceptionss::Forbidden.new(e.message)

  #   rescue => e
  #     logger.error(e.message)
  #     raise Exceptionss::Unrecoverable
  #   end
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
end
