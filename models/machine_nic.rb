class MachineNic < Base::MachineNic
  attr_accessor :vm,
                :stats,
                :key,
                :vnic

  def readings(inode, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    logger.info('machine_nic.readings')

    #Create machine nic readings
    readings_from_stats(stats)
  end

  def readings_from_stats(performance_metrics)
    # Helper Method for creating readings objects.
    if performance_metrics.is_a? (RbVmomi::VIM::PerfEntityMetric)
      performance_metrics.sampleInfo.each_with_index.map do |x,i|
        if performance_metrics.value.empty?
          MachineNicReading.new(
              receive:    0,
              transmit:   0,
              date_time: x.timestamp
          )
        else
          receive_metric =  "148.#{key}"
          transmit_metric = "149.#{key}"
          metric_readings = Hash[performance_metrics.value.map{|s| ["#{s.id.counterId}.#{s.id.instance}",s.value]}]
          MachineNicReading.new(
              date_time:  x.timestamp,
              receive:    metric_readings[receive_metric].nil? ? 0 : metric_readings[receive_metric][i] == -1 ? 0 : metric_readings[receive_metric][i],
              transmit:   metric_readings[transmit_metric].nil? ? 0 : metric_readings[transmit_metric][i] == -1 ? 0 : metric_readings[transmit_metric][i]
          )
        end
      end
    else
      Array.new
    end
  end
end