require 'java'
Dir['lib/java/**/*.jar'].each do |jar|
  $CLASSPATH << jar
  require jar
end
$CLASSPATH << "#{PADRINO_ROOT}/lib/java"
java_import "VMwareInventory"

class Machine < Base::Machine
  include TorqueBox::Messaging::Backgroundable

  attr_accessor :vm,
                :stats



  KB = 1024
  MB = 1024**2
  GB = 1024**3
  TB = 1024**4
  # @@cache = {}
  @@hz_cache = {}
  
  def stats=(stats)
    @stats = stats
    if @disks.nil?.eql?(false)
      @disks.each do |disk|
        disk.stats = stats
      end
    end

    if @nics.nil?.eql?(false)
      @nics.each do |nic|
        nic.stats = stats
      end
    end
  end

  def create_from_ovf(inode, ovf)
    logger.info("Creating Machine(s) from OVF")

    begin

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  def self.vm_inventory(inode)
    vm_inventory = VMwareInventory.new("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)
    vm_inventory.vmMap.to_hash
  ensure
    vm_inventory.close
  end


  def self.all(inode)
    logger.info('machine.all')
    # machines = self.get_machines_cache(inode.uuid)
    # if machines.nil?.eql?(false)
    #   return machines 
    # end

    begin
      # Set the property collector variable and root folder variables
      property_collector = inode.session.serviceContent.propertyCollector
      root_folder        = inode.session.serviceContent.rootFolder

   
      find_vapp_to_vm = RbVmomi::VIM.TraversalSpec(
        :name      => "vapp_to_vm",
        :type      => "VirtualApp",
        :path      => "vm"
        )

      find_vapp_to_vapp = RbVmomi::VIM.TraversalSpec(
        :name      => "vapp_to_vapp",
        :type      => "VirtualApp",
        :path      => "resourcePool",
        :selectSet => [
          RbVmomi::VIM.SelectionSpec(:name => "vapp_to_vapp"),
          RbVmomi::VIM.SelectionSpec(:name => "vapp_to_vm")
        ]
      )

      selection_spec = RbVmomi::VIM.SelectionSpec(:name => "visit_folders")

      datacenter_to_vm_folder = RbVmomi::VIM.TraversalSpec(
        :name      => "Datacenters",
        :type      => "Datacenter",
        :path      => "vmFolder",
        :skip      => false,
        :selectSet => [selection_spec]
      )

      find_folders = RbVmomi::VIM.TraversalSpec(
        :name      => "visit_folders",
        :type      => "Folder",
        :path      => "childEntity",
        :skip      => false,
        :selectSet => [ selection_spec,datacenter_to_vm_folder,find_vapp_to_vm,find_vapp_to_vapp]
      )

      filter_spec   = RbVmomi::VIM.PropertyFilterSpec(
        :objectSet => [{
                         :obj       => root_folder,
                         :selectSet => [find_folders]
                       }],
        :propSet   => [{ :pathSet => %w(config guest layoutEx recentTask runtime),
                         :type    => "VirtualMachine"
                       }]
      )

      # Retrieve properties for all machines and create machine objects
      vm_properties = property_collector.RetrieveProperties(:specSet => [filter_spec])

      machines = vm_properties.map { |m| new_machine_from_vm(inode,m) }
      # self.set_machines_cache(inode.uuid,machines)
      return machines

    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable
    end
  end

  def all_with_readings(inode, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    Machine.all_with_readings(inode, _interval, _since, _until)
  end

  def self.all_with_readings(inode, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    logger.info("machine.all_with_readings")
    logger.info("localTime: #{Time.now.utc}")

    begin
      # Retrieve all machines and virtual machine references

      vm_inventory = VMwareInventory.new("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)
      vm_inventory.gatherCounters
      startTime = _since.utc.strftime('%Y-%m-%dT%H:%M:%S')+"Z"
      endTime = _until.utc.strftime('%Y-%m-%dT%H:%M:%S')+"Z"
      vm_inventory.readings( startTime.to_java, endTime.to_java)
      # vm_inventory.printVMs();
      machines = vm_inventory.vmMap.to_hash

      # inode.open_session
      # machines            = self.vm_inventory(inode)
      # logger.info(machines.inspect)
      # vms                 = machines.map { |m| m.vm }

      # # Connect to vCenter and set the performance manager variable
      # performance_manager = inode.session.serviceContent.perfManager

      # # Collects Performance information and set the machine.stats object
      # metrics             = { "cpu.usage.average" => "","cpu.usagemhz.average" => "", "mem.consumed.average" => "", "virtualDisk.read.average" => "*", "virtualDisk.write.average" => "*", "net.received.average" => "*", "net.transmitted.average" => "*" }
      # stats               = performance_manager.retrieve_stats(vms, metrics, _interval, _since, _until)
      # stats.each do |stat|
      #   machines.each do |machine|
      #     machine.stats = stat if machine.vm == stat.entity
      #   end
      # end
      
      # Returns update machine array
      machines

    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable
    ensure
      vm_inventory.close
    end
  end

  def self.find_by_uuid(inode, uuid)
    logger.info('Machine.find_by_uuid')

    begin
      # Connect to vCenter and set the property collector and the searchindex variables
      property_collector = inode.session.serviceContent.propertyCollector
      search_index       = inode.session.searchIndex

      # Search for the virtual machine by UUID and set the property filter variable
      vm                 = search_index.FindByUuid :uuid => uuid, :vmSearch => true

      if vm.nil?
        raise Exceptionss::NotFound.new("Machine with UUID of #{uuid} was not found")
      else
        filter_spec   = RbVmomi::VIM.PropertyFilterSpec(
          :objectSet => [{ :obj => vm }],
          :propSet   => [{ :pathSet => %w(config guest layoutEx recentTask runtime),
                           :type    => "VirtualMachine"
                         }]
        )

        # Retrieve properties create the machine object
        vm_properties = property_collector.RetrieveProperties(:specSet => [filter_spec])
        machine       = new_machine_from_vm(inode, vm_properties.first)
      end

      # Return the updated machine object
      machine

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  def self.find_by_uuid_with_readings(inode, uuid, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    logger.info('machine.find_by_uuid_with_readings')

    begin
      machine             = self.find_by_uuid(inode, uuid)
      vms                 = [machine.vm]

      # Connect to vCenter and set the performance manager variable
      performance_manager = inode.session.serviceContent.perfManager

      # Collects Performance information and set the machine.stats property
      metrics             = { "cpu.usage.average" => "","cpu.usagemhz.average" => "", "mem.consumed.average" => "", "virtualDisk.read.average" => "*", "virtualDisk.write.average" => "*", "net.received.average" => "*", "net.transmitted.average" => "*" }
      stats               = performance_manager.retrieve_stats(vms, metrics, _interval, _since, _until)

      machine.stats = stats.first

      # Return updated machine object
      machine
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  def readings(inode, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    begin
      logger.info("machine.readings")

      #Create list of timestamps
      # Time.now.utc.round(5.minutes).utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z  => "2012-12-11T20:20:00.000Z"
      timestamps = { }
      if _since < Time.now.utc
        start  = _since.round(5.minutes).utc
        finish = _until.floor(5.minutes).utc
        if finish <= start
          finish = start+300
        end
        intervals = ((finish - start) / _interval).round
        i         = 1
        while i <= intervals do
          timestamps[start+(i*300)] = false
          logger.info("ts - "+(start+(i*300)).iso8601.to_s)
          i += 1
        end
      end
      #Create machine readings
      logger.info('machine.readings_from_stats')
      result = []
      timestamps.keys.each do |timestamp|
        if stats.key?(timestamp.utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z")
          metrics = stats[timestamp.utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z"]
          cpu_usage = stats["cpu.usage.average"].nil? ? 0 : stats["cpu.usage.average"] == -1 ? 0 : (stats["cpu.usage.average"].to_f / (100**2)).to_f
          memory_bytes = stats["mem.consumed.average"].nil? ? 0 : stats["mem.consumed.average"][i] == -1 ? 0 : stats["mem.consumed.average"][i] * 1024
          result << MachineReading.new({
                                         :interval     => _interval,
                                         :cpu_usage    => cpu_usage,
                                         :memory_bytes => memory_bytes,
                                         :date_time    => timestamp.iso8601.to_s }
          )
        else
          result << MachineReading.new({
                                         :interval     => _interval,
                                         :cpu_usage    => 0,
                                         :memory_bytes => 0,
                                         :date_time    => timestamp.iso8601.to_s }
          )
        end
      end
      # performance_manager = inode.session.serviceContent.perfManager
      # if stats.is_a?(RbVmomi::VIM::PerfEntityMetric)
      #   stats.sampleInfo.each_with_index.map do |x, i|
      #     if stats.value.empty?.eql?(false)
      #       cpu_metric_usagemhz = "#{performance_manager.perfcounter_hash["cpu.usagemhz.average"].key}."
      #       cpu_metric_usage = "#{performance_manager.perfcounter_hash["cpu.usage.average"].key}."
      #       memory_metric = "#{performance_manager.perfcounter_hash["mem.consumed.average"].key}."
      #       metric_readings = Hash[stats.value.map { |s| ["#{s.id.counterId}.#{s.id.instance}", s.value] }]
      #       logger.info "memory_metric:\n#{metric_readings[memory_metric].inspect}\n"
      #       logger.info "cpu_metric_usage:\n#{metric_readings[cpu_metric_usage].inspect}\n"
      #       result << MachineReading.new({
      #                                      :interval     => x.interval,
      #                                      :date_time    => x.timestamp,
      #                                      :cpu_usage    => metric_readings[cpu_metric_usage].nil? ? 0 : metric_readings[cpu_metric_usage][i] == -1 ? 0 : (metric_readings[cpu_metric_usage][i].to_f / (100**2)).to_f,
      #                                      :memory_bytes => metric_readings[memory_metric].nil? ? 0 : metric_readings[memory_metric][i] == -1 ? 0 : metric_readings[memory_metric][i] * 1024 }
      #       )
      #       timestamps[x.timestamp] = true
      #       logger.debug("Machine="+@name)
      #       logger.debug("cpu.usage.average="+metric_readings[cpu_metric_usage][i].to_s)
      #       logger.debug("CPU Count="+cpu_count.to_s)
      #       logger.debug("CPU Speed="+cpu_speed.to_s)
      #       logger.debug("CPU Metric Usage="+(metric_readings[cpu_metric_usage][i].to_f / (100**2)).to_s)
      #       logger.debug("cpu.usagemhz.average="+metric_readings[cpu_metric_usagemhz][i].to_s)
      #     end
      #   end
      # end
      # timestamps.keys.each do |timestamp|
      #   if timestamps[timestamp].eql?(false)
      #     result << MachineReading.new({
      #                                    :interval     => _interval,
      #                                    :cpu_usage    => 0,
      #                                    :memory_bytes => 0,
      #                                    :date_time    => timestamp.iso8601.to_s }
      #     )
      #   end
      # end
      result

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  def start(inode)
    logger.info("machine.start")

    begin
      vm.PowerOnVM_Task.wait_for_completion
      @power_state = "starting"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptionss::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptionss::Unrecoverable
    end
  end

  def stop(inode)
    logger.info("machine.stop")

    begin
      vm.ShutdownGuest
      @power_state = "stopping"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptionss::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptionss::Unrecoverable
    end
  end

  def restart(inode)
    logger.info("machine.restart")

    begin
      vm.RebootGuest
      @power_state = "restarting"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptionss::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptionss::Unrecoverable
    end
  end

  def force_stop(inode)
    logger.info("machine.force_stop")

    begin
      vm.PowerOffVM_Task.wait_for_completion
      @power_state = "stopping"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptionss::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptionss::Unrecoverable
    end
  end

  def force_restart(inode)
    logger.info("machine.force_restart")

    begin
      vm.ResetVM_Task.wait_for_completion
      @power_state = "restarting"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptionss::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptionss::Unrecoverable
    end
  end

  def save(inode)
    logger.info("machine.save")
    raise Exceptionss::NotImplemented
  end

  def delete(inode)
    logger.info("machine.delete")

    begin
      vm.Destroy_Task.wait_for_completion
      @power_state = "deleted"

    rescue RbVmomi::Fault => e
      logger.error(e.message)
      raise Exceptionss::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise Exceptionss::Unrecoverable
    end
  end

  def nics=(_nics)
    @nics = _nics.map {|nic| MachineNic.new(nic)}
  end

  def disks=(_disks)
    @disks = _disks.map {|disk| MachineDisk.new(disk)}
  end


  private

  # def self.get_machines_cache(uuid)
  #   @@cache[uuid]
  # end

  # def self.set_machines_cache(uuid,machines)
  #   @@cache[uuid] = machines
  # end

  def self.get_host_hz(inode,moref)
    host_cache = @@hz_cache[inode.uuid]
    if host_cache.nil?
      @@hz_cache[inode.uuid] = {}
    end
    @@hz_cache[inode.uuid][moref]
  end

  def self.set_host_hz(inode,moref,hz)    
    host_cache = @@hz_cache[inode.uuid]
    if host_cache.nil?
      @@hz_cache[inode.uuid] = {}
    end
    @@hz_cache[inode.uuid][moref] = hz
    hz
  end

  # Helper method for creating machine objects..
  def self.new_machine_from_vm(inode, properties)
    logger.info('machine.new_machine_from_vm')

    begin
      properties_hash = properties.to_hash
      logger.debug('Machine Name='+properties_hash["config"].name.to_s)
      hz = self.get_host_hz(inode, properties_hash["runtime"].host._ref)
      if hz.nil?    
        logger.info('adding host hz cache for '+properties_hash["runtime"].host._ref)
        hz = self.set_host_hz(inode, properties_hash["runtime"].host._ref,properties_hash["runtime"].host.hardware.cpuInfo.hz)
      else
        logger.info('found host hz cache for '+properties_hash["runtime"].host._ref)
      end
      Machine.new({
                    :uuid           => properties_hash["config"].uuid,
                    :name           => properties_hash["config"].name,
                    :cpu_count      => properties_hash["config"].hardware.numCPU,
                    :cpu_speed      => hz / 1000000,
                    :maximum_memory => properties_hash["config"].hardware.memoryMB,
                    :system         => build_system(properties),
                    :disks          => build_disks(properties),
                    :nics           => build_nics(properties),
                    :guest_agent    => properties_hash["guest"].toolsStatus == "toolsNotInstalled" ? false : true,
                    :power_state    => convert_power_state(properties_hash["guest"].toolsStatus, properties_hash["runtime"].powerState),
                    :vm             => properties.obj,
                    :stats          => []
                  }
      )
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

# Helper Method for creating system objects.
  def self.build_system(properties)
    logger.info('machine.build_system')

    begin
      properties_hash = properties.to_hash
      x64_arch        = properties_hash["config"].guestId.include? "64"

      MachineSystem.new({
                          :architecture     => x64_arch ? "x64" : "x32",
                          :operating_system => properties_hash["config"].guestId }
      )
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

# Helper Method to calculate disk used space
  def self.build_disk_files(disk_key, file_layout)
    logger.info('machine.build_disk_files')
    begin
      disk_files = []
      if !file_layout.disk.empty?
        logger.info('file_layout.disk='+file_layout.disk.inspect)
        file_layout.disk.find { |n| n.key.eql?(disk_key) }.chain.map do |f|
          f.fileKey.map do |k|
            disk_files << file_layout.file.find { |m| m.key.eql?(k) }
          end
        end
      end
      disk_files
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  # Helper Method for creating disk objects.
  def self.build_disks(properties)
    logger.info('machine.build_disks')

    begin
      properties_hash = properties.to_hash
      debug_name = properties_hash["config"].name
      vm_disks        = properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualDisk)
      vm_disks.map do |vdisk|
        logger.debug(debug_name+" Disk "+vdisk.deviceInfo.label.to_s+" size "+(vdisk.capacityInKB * KB / GB).to_s)
        MachineDisk.new({
                          :uuid         => vdisk.backing.uuid,
                          :name         => vdisk.deviceInfo.label,
                          :maximum_size => vdisk.capacityInKB * KB / GB,
                          :vdisk        => vdisk,
                          :vdisk_files  => build_disk_files(vdisk.key, properties_hash["layoutEx"]),
                          :type         => 'Disk',
                          :thin         => vdisk.backing.thinProvisioned,
                          :key          => vdisk.key,
                          :vm           => properties.obj,
                          :stats        => []
        })
      end
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  # Helper Method for creating nic objects.
  def self.build_nics(properties)
    logger.info('machine.build_nics')

    begin
      properties_hash = properties.to_hash
      vm_nics         = properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualE1000) + properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualPCNet32) + properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualVmxnet)

      vm_nics.map do |vnic|

        if properties_hash["guest"].net.empty?
          nic_ip_address = "Unknown"
        elsif properties_hash["guest"].net.find { |x| x.deviceConfigId == vnic.key }.nil?
          nic_ip_address = "Unknown"
        else
          nic_ip_address = properties_hash["guest"].net.find { |x| x.deviceConfigId == vnic.key }.ipAddress.join(",")
        end

        MachineNic.new({
                         :uuid        => "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa#{vnic.key}",
                         :name        => vnic.deviceInfo.label,
                         :mac_address => vnic.macAddress,
                         :ip_address  => nic_ip_address,
                         :vnic        => vnic,
                         :vm          => properties.obj,
                         :stats       => [],
                         :key         => vnic.key
        })
      end
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
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
      raise Exceptions::Unrecoverable
    end
  end



end
