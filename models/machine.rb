class Machine < Base::Machine
  attr_accessor :vm,
                :stats

  KB = 1024
  MB = 1024**2
  GB = 1024**3
  TB = 1024**4

  def stats=(stats)
    @stats = stats

    @disks.each do |disk|
      disk.stats = stats
    end

    @nics.each do |nic|
      nic.stats = stats
    end
  end

  def create_from_ovf(inode, ovf)
    logger.info("Creating Machine(s) from OVF")

    begin

    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

  def self.all(inode)
    logger.info('machine.all')

    begin
      # Set the property collector variable and root folder variables
      property_collector = inode.session.serviceContent.propertyCollector
      root_folder =  inode.session.serviceContent.rootFolder

      # Create a filter to retrieve properties for all machines
      recurse_folders = RbVmomi::VIM.SelectionSpec(
          :name => "ParentFolder"
      )

      find_machines = RbVmomi::VIM.TraversalSpec(
          :name => "Datacenters",
          :type => "Datacenter",
          :path => "vmFolder",
          :skip => false,
          :selectSet => [recurse_folders]
      )

      find_folders = RbVmomi::VIM.TraversalSpec(
          :name => "ParentFolder",
          :type => "Folder",
          :path => "childEntity",
          :skip => false,
          :selectSet => [recurse_folders,find_machines]
      )

      filter_spec = RbVmomi::VIM.PropertyFilterSpec(
          :objectSet => [{
                             :obj => root_folder,
                             :selectSet => [find_folders]
                         }],
          :propSet => [{:pathSet => %w(config guest layoutEx recentTask runtime),
                        :type => "VirtualMachine"
                       }]
      )

      # Retrieve properties for all machines and create machine objects
      vm_properties = property_collector.RetrieveProperties(:specSet => [filter_spec])
      vm_properties.map {|m| new_machine_from_vm (m)}

    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

  def self.all_with_readings(inode, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    logger.info("machine.all_with_readings")

    begin
      # Retrieve all machines and virtual machine references
      machines = self.all(inode)
      vms = machines.map {|m| m.vm}

      # Connect to vCenter and set the performance manager variable
      performance_manager = inode.session.serviceContent.perfManager

      # Collects Performance information and set the machine.stats object
      metrics = {"cpu.usagemhz.average" => "","mem.consumed.average" => "","virtualDisk.read.average" => "*","virtualDisk.write.average" => "*","net.received.average" => "*","net.transmitted.average" => "*"}
      stats = performance_manager.retrieve_stats(vms,metrics,_interval,_since,_until)
      stats.each do |stat|
        machines.each do |machine|
          if stat.empty? then   #TODO: Does not work when there is at least one reading
            stat = add_missing_timestamps(machine.vm, _since, _until, _interval)
          end
          machine.stats = stat if machine.vm == stat.entity
        end
      end

      # Returns update machine array
      machines

    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

  def self.find_by_uuid(inode, uuid)
    logger.info('Machine.find_by_uuid')

    begin
      # Connect to vCenter and set the property collector and the searchindex variables
      property_collector = inode.session.serviceContent.propertyCollector
      search_index = inode.session.searchIndex

      # Search for the virtual machine by UUID and set the property filter variable
      vm = search_index.FindByUuid :uuid => uuid, :vmSearch => true

      if vm.nil?
        raise Exceptions::NotFound.new("Machine with UUID of #{uuid} was not found")
      else
        filter_spec = RbVmomi::VIM.PropertyFilterSpec(
            :objectSet => [{:obj => vm}],
            :propSet => [{:pathSet => %w(config guest layoutEx recentTask runtime),
                          :type => "VirtualMachine"
                         }]
        )

        # Retrieve properties create the machine object
        vm_properties = property_collector.RetrieveProperties(:specSet => [filter_spec])
        machine = new_machine_from_vm(vm_properties.first)
      end

      # Return the updated machine object
      machine

    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

  def self.find_by_uuid_with_readings(inode, uuid, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    logger.info('machine.find_by_uuid_with_readings')

    begin
      machine = self.find_by_uuid(inode,uuid)
      vms = [machine.vm]

      # Connect to vCenter and set the performance manager variable
      performance_manager = inode.session.serviceContent.perfManager

      # Collects Performance information and set the machine.stats property
      metrics = {"cpu.usagemhz.average" => "","mem.consumed.average" => "","virtualDisk.read.average" => "*","virtualDisk.write.average" => "*","net.received.average" => "*","net.transmitted.average" => "*"}
      stats = performance_manager.retrieve_stats(vms,metrics,_interval,_since,_until)
      if stats.empty? then
        stats = add_missing_timestamps(machine.vm, _since, _until, _interval)
      end

      machine.stats = stats.first

      # Return updated machine object
      machine
    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

  def readings(inode, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    begin
      logger.info("machine.readings")

      #Create machine readings
      readings_from_stats(stats)

    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

  def start(inode)
    logger.info("machine.start")

    begin
      vm.PowerOnVM_Task.wait_for_completion
      @power_state = "starting"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptions::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  def stop(inode)
    logger.info("machine.stop")

    begin
      vm.ShutdownGuest
      @power_state = "stopping"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptions::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  def restart(inode)
    logger.info("machine.restart")

    begin
      vm.RebootGuest
      @power_state = "restarting"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptions::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  def force_stop(inode)
    logger.info("machine.force_stop")

    begin
      vm.PowerOffVM_Task.wait_for_completion
      @power_state = "stopping"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptions::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  def force_restart(inode)
    logger.info("machine.force_restart")

    begin
      vm.ResetVM_Task.wait_for_completion
      @power_state = "restarting"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptions::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  def save(inode)
    logger.info("machine.save")
    raise Exceptions::NotImplemented
  end

  def delete(inode)
    logger.info("machine.delete")

    begin
      vm.Destroy_Task.wait_for_completion
      @power_state = "deleted"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptions::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  private

  # Helper method for creating machine objects..
  def self.new_machine_from_vm(properties)
    logger.info('machine.new_machine_from_vm')

    begin
      properties_hash = properties.to_hash
      last_task = properties_hash["recentTask"].empty? ? "none" : properties_hash["recentTask"].last.info.descriptionId
      Machine.new(
          uuid:             properties_hash["config"].uuid,
          name:             properties_hash["config"].name,
          cpu_count:        properties_hash["config"].hardware.numCPU,
          cpu_speed:        properties_hash["runtime"].host.hardware.cpuInfo.hz / 1000000 ,
          maximum_memory:   properties_hash["config"].hardware.memoryMB,
          system:           build_system(properties),
          disks:            build_disks(properties),
          nics:             build_nics(properties),
          guest_agent:      properties_hash["guest"].toolsStatus == "toolsNotInstalled" ? false : true,
          power_state:      convert_power_state(properties_hash["guest"].toolsStatus, properties_hash["runtime"].powerState,last_task),
          vm:               properties.obj,
          stats:            []
      )
    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

  # Helper Method for creating readings objects.
  def readings_from_stats(performance_metrics)
    logger.info('machine.readings_from_stats')

    begin
      if performance_metrics.is_a? (RbVmomi::VIM::PerfEntityMetric)
        performance_metrics.sampleInfo.each_with_index.map do |x,i|
          if performance_metrics.value.empty?
            MachineReading.new(
                interval:     x.interval,
                date_time:    x.timestamp,
                cpu_usage:    0,
                memory_bytes: 0
            )
          else
            cpu_metric = "6."
            memory_metric = "98."
            metric_readings = Hash[performance_metrics.value.map{|s| ["#{s.id.counterId}.#{s.id.instance}",s.value]}]
            MachineReading.new(
                interval:     x.interval,
                date_time:    x.timestamp,
                cpu_usage:    metric_readings[cpu_metric].nil? ? 0 : metric_readings[cpu_metric][i] == -1 ? 0 : metric_readings[cpu_metric][i],
                memory_bytes: metric_readings[memory_metric].nil? ? 0 : metric_readings[memory_metric][i] == -1 ? 0: metric_readings[memory_metric][i]
            )
          end
        end
      else
        Array.new
      end
    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

# Helper Method for creating system objects.
  def self.build_system(properties)
    logger.info('machine.build_system')

    begin
      properties_hash = properties.to_hash
      x64_arch = properties_hash["config"].guestId.include? "64"

      MachineSystem.new(
          architecture:     x64_arch ? "x64" : "x32",
          operating_system: properties_hash["config"].guestId
      )
    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end
#Helper Method to add missing timestamps
  def self.add_missing_timestamps(_vm, _since, _until, _interval)
    logger.info('machine.add_missing_timestamps')

    begin
      stats = []
      no_of_readings = ((_until - _since) / _interval).to_i
      no_of_readings.times do
        reading = RbVmomi::VIM::PerfEntityMetric(
                    :sampleInfo => [RbVmomi::VIM::PerfSampleInfo(:timestamp => Time.now.utc,:interval => _interval)],
                    :value => [],
                    :entity => _vm)
        stats << reading
      end

      stats
    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end
# Helper Method to calculate disk used space
  def self.build_disk_files(disk_key, file_layout)
    logger.info('machine.build_disk_files')

    begin
      disk_files = []
      file_layout.disk.find{|n| n.key==disk_key}.chain.map do |f|
        f.fileKey.map do |k|
          disk_files << file_layout.file.find{|m| m.key==k}
        end
      end
      disk_files
    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

  # Helper Method for creating disk objects.
  def self.build_disks(properties)
    logger.info('machine.build_disks')

    begin
      properties_hash = properties.to_hash
      vm_disks = properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualDisk)

      vm_disks.map do |vdisk|
        MachineDisk.new(
            uuid:           vdisk.backing.uuid,
            name:           vdisk.deviceInfo.label,
            maximum_size:   vdisk.capacityInKB * KB / GB,
            vdisk:          vdisk,
            vdisk_files:    build_disk_files(vdisk.key,properties_hash["layoutEx"]),
            type:           'Disk',
            thin:           vdisk.backing.thinProvisioned,
            key:            vdisk.key,
            vm:             properties.obj,
            stats:          []
        )
      end
    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

  # Helper Method for creating nic objects.
  def self.build_nics(properties)
    logger.info('machine.build_nics')

    begin
      properties_hash = properties.to_hash
      vm_nics = properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualE1000) + properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualPCNet32) + properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualVmxnet)

      vm_nics.map do |vnic|

        if properties_hash["guest"].net.empty?
          nic_ip_address = "Unknown"
        elsif
        properties_hash["guest"].net.find{|x| x.deviceConfigId == vnic.key}.nil?
          nic_ip_address = "Unknown"
        else
          nic_ip_address =  properties_hash["guest"].net.find{|x| x.deviceConfigId == vnic.key}.ipAddress.join(",")
        end

        MachineNic.new(
            uuid:        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa#{vnic.key}",
            name:         vnic.deviceInfo.label,
            mac_address:  vnic.macAddress,
            ip_address:   nic_ip_address,
            vnic:         vnic,
            vm:           properties.obj,
            stats:        [],
            key:          vnic.key
        )
      end
    rescue => e
      logger.error(e.message)
      raise Exception::Unrecoverable
    end
  end

  # Helper Method for converting machine power states.
  def self.convert_power_state(tools_status, power_status, last_task)
    logger.info('machine.convert_power_state')

    begin
      status = "#{tools_status}|#{power_status}"

      case status
        when "toolsOk|poweredOn" then "started"
        when "toolsOld|poweredOn" then "started"
        when "toolsNotInstalled|poweredOn" then "started"
        when "toolsNotRunning|poweredOff" then "stopped"
        when "toolsOld|poweredOff" then "stopped"
        when "toolsNotInstalled|poweredOff" then "stopped"
        when "toolsNotRunning|poweredOn"
          case last_task
            when "VirtualMachine.powerOn" then "starting"
            when "VirtualMachine.powerOff" then "stopping"
            when "VirtualMachine.shutdownGuest" then "stopping"
            when "VirtualMachine.rebootGuest" then "restarting"
            when "VirtualMachine.reset" then "restarting"
            else "started"
          end
        else "Unknown"
      end
   rescue => e
     logger.error(e.message)
     raise Exception::Unrecoverable
   end
  end

end
