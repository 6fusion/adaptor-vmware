module Implementor::MachineNic
  extends_host_with :ClassMethods

  module ClassMethods
  end

  def readings(i_node, _since = Time.now.utc.beginning_of_month, _until = Time.now.utc)
    logger.info('machine_nic.readings')

    readings = Array.new
    1.upto(2) do |j|
      reading = MachineNicReading.new(
        receive: 8*1024,
        transmit:  16*1024
      )

      readings << reading
    end

    readings
  end
end