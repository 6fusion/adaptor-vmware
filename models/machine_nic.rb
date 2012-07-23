# @api public
class MachineNic < Base::MachineNic
  attr_accessor :vm,
                :stats,
                :key

  # This is where you would call your cloud service and
  # find a specific machine's nic's readings.
  # This request should support since (start_date) and until (end_date)
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @param [Time] _since The beginning date/time for the requested readings
  # @param [Time] _until The ending date/time for the requested readings
  # @return [Machine]
  def readings(i_node, _since = Time.now.utc - 1800, _until = Time.now.utc)
    logger.info('machine_nic.readings')

    #Create machine nic readings
    readings_from_stats(stats)
  end

  def readings_from_stats(performance_metrics)
    # Helper Method for creating readings objects.
    performance_metrics.sampleInfo.each_with_index.map do |x,i|
      if performance_metrics.value.empty?
        MachineNicReading.new(
            receive:    0,
            transmit:   0
        )
      else
        metric_readings = Hash[performance_metrics.value.map{|s| ["#{s.id.counterId}.#{s.id.instance}",s.value]}]
        MachineNicReading.new(
            receive:    metric_readings["148.#{key}"].nil? ? 0 : metric_readings["148.#{key}"][i].to_s,
            transmit:   metric_readings["149.#{key}"].nil? ? 0 : metric_readings["149.#{key}"][i].to_s
        )
      end
    end
  end
end