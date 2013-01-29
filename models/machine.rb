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
    inode.close_vm_inventory(vm_inventory)
  end



  def self.all(inode)
    self.vm_inventory(inode)
  end

  def self.all_with_readings(inode, _interval = 300,  _since = 10.minutes.ago.utc, _until = 5.minutes.ago.utc)

    begin
      # Retrieve all machines and virtual machine references

      vm_inventory = VMwareInventory.new("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)
      startTime = _since.floor(5.minutes).utc.strftime('%Y-%m-%dT%H:%M:%S')+"Z"
      endTime = _until.round(5.minutes).utc.strftime('%Y-%m-%dT%H:%M:%S')+"Z"
      vm_inventory.readings( startTime.to_java, endTime.to_java)
      # DEBUG
      # vm_inventory.printVMs()

      machines = vm_inventory.vmMap.to_hash.map {|_, vm| Machine.new(vm)}

      # Returns update machine array
      machines

    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable, e.message
    ensure
      inode.close_vm_inventory(vm_inventory)
    end
  end

  def self.find_by_uuid(inode, uuid)
    begin
      vm_inventory = VMwareInventory.new("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)
      props = vm_inventory.findByUuid(uuid)
      unless props.nil?
        self.new(props.to_hash)
      else
        raise Exceptions::NotFound 
      end 
    ensure
      inode.close_vm_inventory(vm_inventory)
    end
  end
 

  def self.find_by_uuid_with_readings(inode, uuid, _interval = 300, _since = 10.minutes.ago.utc, _until =  5.minutes.ago.utc)
    begin
      vm_inventory = VMwareInventory.new("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)

      startTime = _since.floor(5.minutes).utc.strftime('%Y-%m-%dT%H:%M:%S')+"Z"
      endTime = _until.round(5.minutes).utc.strftime('%Y-%m-%dT%H:%M:%S')+"Z"
      props = vm_inventory.findByUuidWithReadings(uuid.to_java, startTime.to_java, endTime.to_java)
      unless props.nil?
        vm = self.new(props.to_hash)
      else
        raise Exceptions::NotFound 
      end 
      vm        
    ensure
      inode.close_vm_inventory(vm_inventory)
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
      raise Exceptions::Unrecoverable, e.message
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

  class << self
    include ::NewRelic::Agent::MethodTracer
    add_method_tracer :vm_inventory
    add_method_tracer :all
    add_method_tracer :all_with_readings
    add_method_tracer :find_by_uuid
    add_method_tracer :find_by_uuid_with_readings
  end


end
