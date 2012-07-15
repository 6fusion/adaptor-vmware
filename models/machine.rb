# @api public
class Machine < Base::Machine
  attr_accessor :vm_moref

  # This is where you would call your cloud service and get a list of machines
  #
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [Array<Machine>]
  def self.all(i_node)
    logger.info('Machine.all')

    credentials = parse_credentials(i_node.credentials)
    vim = RbVmomi::VIM.connect :host => i_node.connection, :user => credentials["username"], :password => credentials["password"] , :insecure => true
    pc = vim.serviceContent.propertyCollector

    filterSpec = RbVmomi::VIM.PropertyFilterSpec(
        :objectSet => [{
                           :obj => vim.rootFolder,
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
        :propSet => [{:pathSet => [],
                      :type => "VirtualMachine"
                     }]
    )

    vms = pc.RetrieveProperties(:specSet => [filterSpec])

    machines = Array.new

    vms.each do |m|
      #Create a new machine object from the vm object
      machine = new_machine_from_vm (m.obj)

      # Add the Machine object to the @machines array
      machines << machine
    end

    machines
  end

  # This is where you would call your cloud service and find the machine matching
  # the uuid passed.
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @param [String] uuid The specific identifier for the Machine
  # @return [Machine]
  def self.find_by_uuid(i_node, uuid)
    logger.info('Machine.find_by_uuid')
    machine = Machine.new(
      uuid:             uuid,
      name:             'My Fake Machine',
      cpu_count:        rand(4),
      cpu_speed:        rand(2000),
      maximum_memory:   32*1024*1024,
      system:           build_system(),
      disks:            build_disks(),
      nics:             build_nics(),
      guest_agent:      true,
      power_state:      'poweredOn'
    )

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
  def readings(i_node, _since = Time.now.utc.beginning_of_month, _until = Time.now.utc)
    logger.info('machine.readings')

    readings = Array.new
    1.upto(5) do |i|
      reading = MachineReading.new(
        interval:     3600,
        date_time:    Time.at((_until.to_f - _since.to_f) * rand + _since.to_f),
        cpu_usage:    1400,
        memory_bytes: rand(32) * 1024 * 1024
      )

      readings << reading
    end

    readings
  end

  # Management
  # This is where you would call your cloud service and power on a machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def power_on(i_node)
    logger.info("machine.power_on")
    raise Exceptions::NotImplemented
  end

  # This is where you would call your cloud service and power off a machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def power_off(i_node)
    logger.info("machine.power_off")
    raise Exceptions::NotImplemented
  end

  # This is where you would call your cloud service and restart a machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def restart(i_node)
    logger.info("machine.restart")
    raise Exceptions::NotImplemented
  end

  # This is where you would call your cloud service and shutdown a machine
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @return [nil]
  def shutdown(i_node)
    logger.info("machine.shutdown")
    raise Exceptions::NotImplemented
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
    raise Exceptions::NotImplemented
  end

  private
  #Helper Method for parsing credentials
  def self.parse_credentials(credentials)
    #Converts the credentials in "username|password" format to a hash
    credential_items = credentials.split "|"
    credential_hash = Hash.new
    credential_hash["username"] = credential_items[0]
    credential_hash["password"] = credential_items[1]
    credential_hash
  end

  # Helper method for creating machine objects..
  def self.new_machine_from_vm(vm)
    machine = Machine.new(
        uuid:             vm.config.uuid,
        name:             vm.config.name,
        cpu_count:        vm.config.hardware.numCPU,
        cpu_speed:        vm.runtime.host.hardware.cpuInfo.hz / 1000000 ,
        maximum_memory:   vm.config.hardware.memoryMB,
        system:           build_system(vm),
        disks:            build_disks(vm),
        nics:             build_nics(vm),
        guest_agent:      vm.guest.toolsStatus == "toolsOk" ? true : false,
        power_state:      vm.runtime.powerState,
        vm_moref:         vm
    )

    machine
  end

  # Helper Method for creating system objects.
  def self.build_system(machine)
    logger.info('Machine.build_system')

    x64_arch = machine.config.guestId.include? "64"

    MachineSystem.new(
        architecture:     x64_arch ? "x64" : "x32",
        operating_system: machine.config.guestId
    )
  end

  # Helper Method for creating disk objects.
  def self.build_disks(machine)
    logger.info('Machine.build_disks')

    vm_disks = machine.config.hardware.device.grep(RbVmomi::VIM::VirtualDisk)
    machine_disks = Array.new
    vm_disks.each do |vdisk|
      machine_disk = MachineDisk.new(
          uuid:         "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa#{vdisk.key}",
          name:         vdisk.deviceInfo.label,
          maximum_size: vdisk.capacityInKB / 1000000,
          type:         'Disk'
      )

      machine_disks << machine_disk
    end

    machine_disks
  end

  # Helper Method for creating nic objects.
  def self.build_nics(machine)
    logger.info('Machine.build_nics')

    vm_nics = machine.config.hardware.device.grep(RbVmomi::VIM::VirtualE1000) + machine.config.hardware.device.grep(RbVmomi::VIM::VirtualPCNet32) + machine.config.hardware.device.grep(RbVmomi::VIM::VirtualVmxnet)

    machine_nics = Array.new
    vm_nics.each do |vnic|
      machine_nic = MachineNic.new(
          uuid:        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa#{vnic.key}",
          name:        vnic.deviceInfo.label,
          mac_address: vnic.macAddress,
          ip_address:  machine.guest.net.empty? ? "Unknown" : machine.guest.net.find{|x| x.deviceConfigId == vnic.key}.ipAddress
      )

      machine_nics << machine_nic
    end

    machine_nics
  end
end
