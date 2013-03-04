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

  # include ::NewRelic::Agent::MethodTracer

  attr_accessor :external_vm_id,
                :external_host_id,
                :stats

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

  def create_from_ovf(inode, ovf)
    logger.info("Creating Machine(s) from OVF")

    begin
      vmware_adaptor = inode.connect("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)
      #do something like deploy an OVF!
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
  add_method_tracer :create_from_ovf

  def self.vmware_adaptor(inode)
    begin
      vmware_adaptor = inode.vmware_api_adaptor.connect("https://#{inode.host_ip_address}/sdk", inode.user, inode.password)
      # vmware_adaptor.gatherVirtualMachines
      # vmware_adaptor.vmMap.to_hash
    rescue Vim::InvalidLogin => e
      raise Exceptions::Forbidden, "Invalid Login"
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable, e.to_s
    ensure
      inode.close_connection
    end
  end

  def self.all(inode)
    inode.vmware_api_adaptor.virtual_machines
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
  add_method_tracer :readings

  # def start(inode)
  #   logger.info("machine.start")
  #   machine = inode.vmware_api_adaptor.start(uuid)
  # end

  # def stop(inode)
  #   logger.info("machine.stop")
  #   machine = inode.vmware_api_adaptor.stop(uuid)
  # end

  # def restart(inode)
  #   logger.info("machine.restart")
  #   machine = inode.vmware_api_adaptor.restart(uuid)
  # end

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
    add_method_tracer :vmware_adaptor
    add_method_tracer :all
    add_method_tracer :all_with_readings
    add_method_tracer :find_by_uuid
    add_method_tracer :find_by_uuid_with_readings
  end


end
