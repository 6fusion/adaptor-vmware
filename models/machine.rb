# @api public
class Machine < Base::Machine
  attr_accessor :vm,
                :stats

  def stats=(stats)
    @stats = stats

    @disks.each do |disk|
      disk.stats = stats
    end

    @nics.each do |nic|
      nic.stats = stats
    end
  end

  # This is where you would call your cloud service and get a list of machines
  #
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [Array<Machine>]
  def self.all(i_node)
    logger.info('machine.all')

    # Connect to vCenter and set the property collector variable
    connection = RbVmomi::VIM.connect :host => i_node.connection, :user => i_node.credentials_hash["username"], :password => i_node.credentials_hash["password"] , :insecure => true
    property_collector = connection.serviceContent.propertyCollector

    # Create a filter to retrieve properties for all machines
    filter_spec = RbVmomi::VIM.PropertyFilterSpec(
        :objectSet => [{
                           :obj => connection.rootFolder,
                           :selectSet => [RbVmomi::VIM.TraversalSpec(
                                              :name => "RootFolders",
                                              :type => "Folder",
                                              :path => "childEntity",
                                              :skip => false,
                                              :selectSet =>[RbVmomi::VIM.TraversalSpec(
                                                                :name => "Datacenters",
                                                                :type => "Datacenter",
                                                                :path => "vmFolder",
                                                                :skip => false,
                                                                :selectSet => [RbVmomi::VIM.TraversalSpec(
                                                                                   :name => "Folders",
                                                                                   :type => "Folder",
                                                                                   :path => "childEntity",
                                                                                   :skip => false,
                                                                                   :selectSet => [RbVmomi::VIM.TraversalSpec(
                                                                                                      :name => "SubFolders",
                                                                                                      :type => "Folder",
                                                                                                      :path => "childEntity",
                                                                                                      :skip => false)]
                                                                               )]
                                                            )]
                                          )]
                       }],
        :propSet => [{:pathSet => %w(config guest runtime),
                      :type => "VirtualMachine"
                     }]
    )

    # Retrieve properties for all machines and create machine objects
    vm_properties = property_collector.RetrieveProperties(:specSet => [filter_spec])
    vm_properties.map {|m| new_machine_from_vm (m)}
  end

  # This is where you would call your cloud service and find all readings for all machines.
  # This request should support since (start_date) and until (end_date)
  #
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @param [Time] _since The beginning date/time for the requested readings
  # @param [Time] _until The ending date/time for the requested readings
  # @return [Array <Machines>]
  def self.all_with_readings(i_node, _since = Time.now.utc - 3600, _until = Time.now.utc)
    logger.info("machine.all_with_readings")

    # Retrieve all machines and virtual machine references
    machines = self.all(i_node)
    vms = machines.map {|m| m.vm}

    # Connect to vCenter and set the performance manager variable
    connection = RbVmomi::VIM.connect :host => i_node.connection, :user => i_node.credentials_hash["username"], :password => i_node.credentials_hash["password"] , :insecure => true
    performance_manager = connection.serviceContent.perfManager

    # Collects Performance information and set the machine.stats object
    metrics = {"cpu.usagemhz.average" => "","mem.consumed.average" => "","virtualDisk.read.average" => "*","virtualDisk.write.average" => "*","net.received.average" => "*","net.transmitted.average" => "*"}
    stats = performance_manager.retrieve_stats(vms,metrics,300,_since,_until)
    stats.each do |stat|
      machines.each do |machine|
        machine.stats = stat if machine.vm == stat.entity
      end
    end

    # Returns update machine array
    machines
  end

  # This is where you would call your cloud service and find the machine matching the uuid passed.
  #
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @param [String] uuid The specific identifier for the Machine
  # @return [Machine]
  def self.find_by_uuid(i_node, uuid)
    logger.info('machine.find_by_uuid')

    # Connect to vCenter and set the property collector and the searchindex variables
    connection = RbVmomi::VIM.connect :host => i_node.connection, :user => i_node.credentials_hash["username"], :password => i_node.credentials_hash["password"] , :insecure => true
    property_collector = connection.serviceContent.propertyCollector
    search_index = connection.searchIndex

    # Search for the virtual machine by UUID and set the property filter variable
    vm = search_index.FindByUuid :uuid => uuid, :vmSearch => true

    if vm.nil?
      raise Exceptions::NotFound
    else
      filter_spec = RbVmomi::VIM.PropertyFilterSpec(
          :objectSet => [{:obj => vm}],
          :propSet => [{:pathSet => %w(config guest runtime),
                        :type => "VirtualMachine"
                       }]
      )

      # Retrieve properties create the machine object
      vm_properties = property_collector.RetrieveProperties(:specSet => [filter_spec])
      machine = new_machine_from_vm(vm_properties.first)
    end

    # Return the updated machine object
    machine
  end

  # This is where you would call your cloud service and find the machine matching the uuid passed and find all readings.
  #
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @param [String] uuid The specific identifier for the Machine
  # @return [Machine]
  # @param [Object] _since
  # @param [Object] _until
  def self.find_by_uuid_with_readings(i_node, uuid, _since = Time.now.utc - 86400, _until = Time.now.utc)
    logger.info('machine.find_by_uuid_with_readings')

    machine = self.find_by_uuid(i_node,uuid)
    vms = [machine.vm]

    # Connect to vCenter and set the performance manager variable
    connection = RbVmomi::VIM.connect :host => i_node.connection, :user => i_node.credentials_hash["username"], :password => i_node.credentials_hash["password"] , :insecure => true
    performance_manager = connection.serviceContent.perfManager

    # Collects Performance information and set the machine.stats property
    metrics = {"cpu.usagemhz.average" => "","mem.consumed.average" => "","virtualDisk.read.average" => "*","virtualDisk.write.average" => "*","net.received.average" => "*","net.transmitted.average" => "*"}
    stats = performance_manager.retrieve_stats(vms,metrics,300,_since,_until)
    machine.stats = stats.first

    # Return updated machine object
    machine
  end

  # This is where you would call your cloud service and
  # find a specific machine's readings.
  # This request should support since (start_date) and until (end_date)
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @param [Time] _since The beginning date/time for the requested readings
  # @param [Time] _until The ending date/time for the requested readings
  # @return [Machine]
  def readings(i_node, _since = Time.now.utc - 1800, _until = Time.now.utc)
    logger.info("machine.readings")

    #Create machine readings
    readings_from_stats(stats)
  end

  # Management
  # This is where you would call your cloud service and power on a machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def power_on(i_node)
    logger.info("machine.power_on")

    begin
      vm.PowerOnVM_Task.wait_for_completion
    rescue => e
      raise Exceptions::Forbidden
    end
  end

  # This is where you would call your cloud service and power off a machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def power_off(i_node)
    logger.info("machine.power_off")
    begin
      vm.PowerOffVM_Task.wait_for_completion
    rescue => e
      raise Exceptions::Forbidden
    end
  end

  # This is where you would call your cloud service and restart a machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def restart(i_node)
    logger.info("machine.restart")

    begin
      vm.RebootGuest
    rescue => e
      raise Exceptions::Forbidden
    end
  end

  # This is where you would call your cloud service and shutdown a machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def shutdown(i_node)
    logger.info("machine.shutdown")

    begin
      vm.ShutdownGuest
    rescue => e
      raise Exceptions::Forbidden
    end
  end

  # This is where you would call your cloud service and unplug a machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def unplug(i_node)
    logger.info("machine.unplug")
    raise Exceptions::NotImplemented
  end

  # This is where you would call your cloud service to create a new virtual machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def save(i_node)
    logger.info("machine.save")
    raise Exceptions::NotImplemented
  end

  # This is where you could call your cloud service to delete a virtual machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def delete(i_node)
    logger.info("machine.delete")

    begin
      vm.Destroy_Task.wait_for_completion
    rescue => e
      raise Exceptions::Forbidden
    end
  end

  private

  # Helper method for creating machine objects..
  def self.new_machine_from_vm(properties)
    logger.info('machine.new_machine_from_vm')
    properties_hash = properties.to_hash

    Machine.new(
        uuid:             properties_hash["config"].uuid,
        name:             properties_hash["config"].name,
        cpu_count:        properties_hash["config"].hardware.numCPU,
        cpu_speed:        properties_hash["runtime"].host.hardware.cpuInfo.hz / 1000000 ,
        maximum_memory:   properties_hash["config"].hardware.memoryMB,
        system:           build_system(properties),
        disks:            build_disks(properties),
        nics:             build_nics(properties),
        guest_agent:      properties_hash["guest"].toolsStatus == "toolsOk" ? true : false,
        power_state:      properties_hash["runtime"].powerState,
        vm:               properties.obj,
        stats:            []
    )
  end

  # Helper Method for creating readings objects.
  def readings_from_stats(performance_metrics)
    logger.info('machine.readings_from_stats')

    performance_metrics.sampleInfo.each_with_index.map do |x,i|
      if performance_metrics.value.empty?
        MachineReading.new(
            interval:     x.interval.to_s,
            date_time:    x.timestamp.to_s,
            cpu_usage:    0,
            memory_bytes: 0
        )
      else
        metric_readings = Hash[performance_metrics.value.map{|s| ["#{s.id.counterId}.#{s.id.instance}",s.value]}]
        MachineReading.new(
            interval:     x.interval.to_s,
            date_time:    x.timestamp.to_s,
            cpu_usage:    metric_readings["6."].nil? ? 0 : metric_readings["6."][i].to_s,
            memory_bytes: metric_readings["98."].nil? ? 0 : metric_readings["98."][i].to_s
        )
      end
    end
  end

# Helper Method for creating system objects.
  def self.build_system(properties)
    logger.info('machine.build_system')
    properties_hash = properties.to_hash
    x64_arch = properties_hash["config"].guestId.include? "64"

    MachineSystem.new(
        architecture:     x64_arch ? "x64" : "x32",
        operating_system: properties_hash["config"].guestId
    )
  end

  # Helper Method for creating disk objects.
  def self.build_disks(properties)
    logger.info('machine.build_disks')
    properties_hash = properties.to_hash
    vm_disks = properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualDisk)

    vm_disks.map do |vdisk|
      MachineDisk.new(
        uuid:           "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa#{vdisk.key}",
        name:           vdisk.deviceInfo.label,
        maximum_size:   vdisk.capacityInKB / 1000000,
        type:           'Disk',
        vm:             properties.obj,
        stats:          [],
        key:            vdisk.key
      )
    end
  end

  # Helper Method for creating nic objects.
  def self.build_nics(properties)
    logger.info('machine.build_nics')
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
          vm:           properties.obj,
          stats:        [],
          key:          vnic.key
      )
    end
  end

end
