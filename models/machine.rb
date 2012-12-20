require 'java'
Dir['lib/java/**/*.jar'].each do |jar|
  $CLASSPATH << jar
  require jar
end
$CLASSPATH << "#{PADRINO_ROOT}/lib/java"
java_import "VMwareInventory"


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

  include ::NewRelic::Agent::MethodTracer

  attr_accessor :external_vm_id,
                :external_host_id,
                :stats



  KB = 1024
  MB = 1024**2
  GB = 1024**3
  TB = 1024**4

  # Used to cache Host CPU hz to avoid making repetitive VMWare SOAP calls
  @@hz_cache = {}
  
  def create_from_ovf(inode, ovf)
    logger.info("Creating Machine(s) from OVF")

    begin

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end
  add_method_tracer :create_from_ovf

  def self.vm_inventory(inode)
    vm_inventory = VMwareInventory.new("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)
    vm_inventory.gatherVirtualMachines
    vm_inventory.vmMap.to_hash
  ensure
    vm_inventory.close
  end



  def self.all(inode)
    self.vm_inventory(inode)
  end

  def all_with_readings(inode, _interval = 300,  _since = 10.minutes.ago.utc, _until = 5.minutes.ago.utc)
    Machine.all_with_readings(inode, _interval, _since, _until)
  end

  def self.all_with_readings(inode, _interval = 300,  _since = 10.minutes.ago.utc, _until = 5.minutes.ago.utc)

    begin
      # Retrieve all machines and virtual machine references

      vm_inventory = VMwareInventory.new("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)
      startTime = _since.utc.strftime('%Y-%m-%dT%H:%M:%S')+"Z"
      endTime = _until.utc.strftime('%Y-%m-%dT%H:%M:%S')+"Z"
      vm_inventory.readings( startTime.to_java, endTime.to_java)
      # DEBUG
      # vm_inventory.printVMs()

      machines = vm_inventory.vmMap.to_hash.map {|_, vm| Machine.new(vm)}

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
    begin
      vm_inventory = VMwareInventory.new("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)
      self.new(vm_inventory.findByUuid(uuid).to_hash)
    ensure
      vm_inventory.close
    end
  end
 

  def self.find_by_uuid_with_readings(inode, uuid, _interval = 300, _since = 10.minutes.ago.utc, _until =  5.minutes.ago.utc)
    begin
      vm_inventory = VMwareInventory.new("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)

      startTime = _since.utc.strftime('%Y-%m-%dT%H:%M:%S')+"Z"
      endTime = _until.utc.strftime('%Y-%m-%dT%H:%M:%S')+"Z"
      props = vm_inventory.findByUuidWithReadings(uuid.to_java, startTime.to_java, endTime.to_java)
      vm = nil
      # logger.info(props.to_hash)
      if !props.nil?
        vm = self.new(props.to_hash)
      end
      vm        
    ensure
      vm_inventory.close
    end
  end

  def readings(_interval = 300, _since = 10.minutes.ago.utc, _until = 5.minutes.ago.utc)
    begin

      #Create list of timestamps
      # Time.now.utc.round(5.minutes).utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z  => "2012-12-11T20:20:00.000Z"
      # timestamps = { }
      # if _since < Time.now.utc
      #   start  = _since.round(5.minutes).utc
      #   finish = _until.floor(5.minutes).utc
      #   if finish <= start
      #     finish = start+300
      #   end
      #   intervals = ((finish - start) / _interval).round
      #   i         = 0
      #   while i < intervals do
      #     timestamps[start+(i*300)] = false
      #     # logger.info("ts - "+(start+(i*300)).iso8601.to_s)
      #     i += 1
      #   end
      # end
      #Create machine readings
      #logger.info('machine.readings_from_stats')
      result = []
      # timestamps.keys.each do |timestamp|
      if !stats.nil? 
        stats.keys.each do | timestamp |  
          logger.info(timestamp)
          # if stats.key?(timestamp.utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z")
            # logger.info("found "+timestamp.utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z")
            metrics = stats[timestamp]
            cpu_usage = metrics["cpu.usage.average"].nil? ? 0 : metrics["cpu.usage.average"] == -1 ? 0 : (metrics["cpu.usage.average"].to_f / (100**2)).to_f
            memory_bytes = metrics["mem.consumed.average"].nil? ? 0 : metrics["mem.consumed.average"] == -1 ? 0 : metrics["mem.consumed.average"] * 1024
            result << MachineReading.new({
                                           :interval     => _interval,
                                           :cpu_usage    => cpu_usage,
                                           :memory_bytes => memory_bytes,
                                           :date_time    => timestamp }
            )
                                           # :date_time    => timestamp.iso8601.to_s }
          # else
          #   logger.info("missing stat"+timestamp.utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z "+stats.to_s)
          #   result << MachineReading.new({
          #                                  :interval     => _interval,
          #                                  :cpu_usage    => 0,
          #                                  :memory_bytes => 0,
          #                                  :date_time    => timestamp.iso8601.to_s }
          #   )
          # end
        # else
        #   logger.info("missing "+timestamp.utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z")
        #   result << MachineReading.new({
        #                                  :interval     => _interval,
        #                                  :cpu_usage    => 0,
        #                                  :memory_bytes => 0,
        #                                  :date_time    => timestamp.iso8601.to_s }
        #   )
        end
      end
      #       logger.debug("CPU Metric Usage="+(metric_readings[cpu_metric_usage][i].to_f / (100**2)).to_s)
      #       logger.debug("cpu.usagemhz.average="+metric_readings[cpu_metric_usagemhz][i].to_s)
      result

    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end
  add_method_tracer :readings

  # def start(inode)
  #   logger.info("machine.start")

  #   begin
  #     vm.PowerOnVM_Task.wait_for_completion
  #     @power_state = "starting"

  #   rescue RbVmomi::Fault => e
  #     logger.error(e.message)
  #     raise Exceptionss::Forbidden.new(e.message)

  #   rescue => e
  #     logger.error(e.message)
  #     raise Exceptionss::Unrecoverable
  #   end
  # end
  # add_method_tracer :start

  # def stop(inode)
  #   logger.info("machine.stop")

  #   begin
  #     vm.ShutdownGuest
  #     @power_state = "stopping"

  #   rescue RbVmomi::Fault => e
  #     logger.error(e.message)
  #     raise Exceptionss::Forbidden.new(e.message)

  #   rescue => e
  #     logger.error(e.message)
  #     raise Exceptionss::Unrecoverable
  #   end
  # end
  # add_method_tracer :stop

  # def restart(inode)
  #   logger.info("machine.restart")

  #   begin
  #     vm.RebootGuest
  #     @power_state = "restarting"

  #   rescue RbVmomi::Fault => e
  #     logger.error(e.message)
  #     raise Exceptionss::Forbidden.new(e.message)

  #   rescue => e
  #     logger.error(e.message)
  #     raise Exceptionss::Unrecoverable
  #   end
  # end
  # add_method_tracer :restart

  # def force_stop(inode)
  #   logger.info("machine.force_stop")

  #   begin
  #     vm.PowerOffVM_Task.wait_for_completion
  #     @power_state = "stopping"

  #   rescue RbVmomi::Fault => e
  #     logger.error(e.message)
  #     raise Exceptionss::Forbidden.new(e.message)

  #   rescue => e
  #     logger.error(e.message)
  #     raise Exceptionss::Unrecoverable
  #   end
  # end
  # add_method_tracer :force_stop

  # def force_restart(inode)
  #   logger.info("machine.force_restart")

  #   begin
  #     vm.ResetVM_Task.wait_for_completion
  #     @power_state = "restarting"

  #   rescue RbVmomi::Fault => e
  #     logger.error(e.message)
  #     raise Exceptionss::Forbidden.new(e.message)

  #   rescue => e
  #     logger.error(e.message)
  #     raise Exceptionss::Unrecoverable
  #   end
  # end
  # add_method_tracer :force_restart

  # def save(inode)
  #   logger.info("machine.save")
  #   raise Exceptionss::NotImplemented
  # end
  # add_method_tracer :save

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
  # add_method_tracer :delete

  def nics=(_nics)
    @nics = _nics.map {|nic| MachineNic.new(nic)}
    if @nics.nil?.eql?(false)
      @nics.each do |nic|
        nic.stats = stats
      end
    end
  end
  add_method_tracer :nics=

  def disks=(_disks)
    @disks = _disks.map {|disk| MachineDisk.new(disk)}
    if @disks.nil?.eql?(false)
       @disks.each do |disk|
         disk.stats = stats
       end
     end      
  end
  add_method_tracer :disks=


  private

  # def self.get_host_hz(inode,moref)
  #   host_cache = @@hz_cache[inode.uuid]
  #   if host_cache.nil?
  #     @@hz_cache[inode.uuid] = {}
  #   end
  #   @@hz_cache[inode.uuid][moref]
  # end

  # def self.set_host_hz(inode,moref,hz)    
  #   host_cache = @@hz_cache[inode.uuid]
  #   if host_cache.nil?
  #     @@hz_cache[inode.uuid] = {}
  #   end
  #   @@hz_cache[inode.uuid][moref] = hz
  #   hz
  # end

  # Helper method for creating machine objects..
#   def self.new_machine_from_vm(inode, properties)
#     logger.info('machine.new_machine_from_vm')

#     begin
#       properties_hash = properties.to_hash
#       logger.debug('Machine Name='+properties_hash["config"].name.to_s)
#       hz = self.get_host_hz(inode, properties_hash["runtime"].host._ref)
#       if hz.nil?    
#         logger.info('adding host hz cache for '+properties_hash["runtime"].host._ref)
#         hz = self.set_host_hz(inode, properties_hash["runtime"].host._ref,properties_hash["runtime"].host.hardware.cpuInfo.hz)
#       else
#         logger.info('found host hz cache for '+properties_hash["runtime"].host._ref)
#       end
#       stats = properties.key?("stats") ? properties["stats"] : {}
#       Machine.new({
#                     :uuid           => properties_hash["config"].uuid,
#                     :external_host_id => properties_hash["host_moref"],
#                     :external_vm_id => properties_hash["moref"],
#                     :name           => properties_hash["config"].name,
#                     :cpu_count      => properties_hash["config"].hardware.numCPU,
#                     :cpu_speed      => hz / 1000000,
#                     :maximum_memory => properties_hash["config"].hardware.memoryMB,
#                     :system         => build_system(properties),
#                     :disks          => build_disks(properties),
#                     :nics           => build_nics(properties),
#                     :guest_agent    => properties_hash["guest"].toolsStatus == "toolsNotInstalled" ? false : true,
#                     :power_state    => convert_power_state(properties_hash["guest"].toolsStatus, properties_hash["runtime"].powerState),
#                     :vm             => properties.obj,
#                     :stats          => stats 
#                   }
#       )
#     rescue => e
#       logger.error(e.message)
#       raise Exceptions::Unrecoverable
#     end
#   end

# # Helper Method for creating system objects.
#   def self.build_system(properties)
#     logger.info('machine.build_system')

#     begin
#       properties_hash = properties.to_hash
#       x64_arch        = properties_hash["config"].guestId.include? "64"

#       MachineSystem.new({
#                           :architecture     => x64_arch ? "x64" : "x32",
#                           :operating_system => properties_hash["config"].guestId }
#       )
#     rescue => e
#       logger.error(e.message)
#       raise Exceptions::Unrecoverable
#     end
#   end

# # Helper Method to calculate disk used space
#   def self.build_disk_files(disk_key, file_layout)
#     logger.info('machine.build_disk_files')
#     begin
#       disk_files = []
#       if !file_layout.disk.empty?
#         logger.info('file_layout.disk='+file_layout.disk.inspect)
#         file_layout.disk.find { |n| n.key.eql?(disk_key) }.chain.map do |f|
#           f.fileKey.map do |k|
#             disk_files << file_layout.file.find { |m| m.key.eql?(k) }
#           end
#         end
#       end
#       disk_files
#     rescue => e
#       logger.error(e.message)
#       raise Exceptions::Unrecoverable
#     end
#   end

#   # Helper Method for creating disk objects.
#   def self.build_disks(properties)
#     logger.info('machine.build_disks')

#     begin
#       properties_hash = properties.to_hash
#       debug_name = properties_hash["config"].name
#       vm_disks        = properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualDisk)
#       vm_disks.map do |vdisk|
#         logger.debug(debug_name+" Disk "+vdisk.deviceInfo.label.to_s+" size "+(vdisk.capacityInKB * KB / GB).to_s)
#         stats = properties.key?("stats") ? properties["stats"] : {}
#         logger.debug("my fing stats are "+stats)
#         MachineDisk.new({
#                           :uuid         => vdisk.backing.uuid,
#                           :name         => vdisk.deviceInfo.label,
#                           :maximum_size => vdisk.capacityInKB * KB / GB,
#                           :controller_key => vdisk.controllerKey,
#                           :vdisk        => vdisk,
#                           :vdisk_files  => build_disk_files(vdisk.key, properties_hash["layoutEx"]),
#                           :type         => 'Disk',
#                           :thin         => vdisk.backing.thinProvisioned,
#                           :key          => vdisk.key,
#                           :vm           => properties.obj,
#                           :stats        => stats 
#         })
#       end
#     rescue => e
#       logger.error(e.message)
#       raise Exceptions::Unrecoverable
#     end
#   end

#   # Helper Method for creating nic objects.
#   def self.build_nics(properties)
#     logger.info('machine.build_nics')

#     begin
#       properties_hash = properties.to_hash
#       vm_nics         = properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualE1000) + properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualPCNet32) + properties_hash["config"].hardware.device.grep(RbVmomi::VIM::VirtualVmxnet)

#       vm_nics.map do |vnic|

#         if properties_hash["guest"].net.empty?
#           nic_ip_address = "Unknown"
#         elsif properties_hash["guest"].net.find { |x| x.deviceConfigId == vnic.key }.nil?
#           nic_ip_address = "Unknown"
#         else
#           nic_ip_address = properties_hash["guest"].net.find { |x| x.deviceConfigId == vnic.key }.ipAddress.join(",")
#         end

#         MachineNic.new({
#                          :uuid        => "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa#{vnic.key}",
#                          :name        => vnic.deviceInfo.label,
#                          :mac_address => vnic.macAddress,
#                          :ip_address  => nic_ip_address,
#                          :vnic        => vnic,
#                          :vm          => properties.obj,
#                          :stats       => [],
#                          :key         => vnic.key
#         })
#       end
#     rescue => e
#       logger.error(e.message)
#       raise Exceptions::Unrecoverable
#     end
#   end

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

  class << self
    include ::NewRelic::Agent::MethodTracer
    add_method_tracer :vm_inventory
    add_method_tracer :all
    add_method_tracer :all_with_readings
    add_method_tracer :find_by_uuid
    add_method_tracer :find_by_uuid_with_readings
  end


end
