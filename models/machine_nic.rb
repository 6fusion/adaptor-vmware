class MachineNic < Base::MachineNic
  attr_accessor :vm,
                :stats,
                :key,
                :vnic

  def readings(inode, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    logger.info('machine_nic.readings')
    timestamps = {}
    if _since < Time.now.utc
      start = Time.round_to_highest_5_minutes(_since)
      finish = Time.round_to_lowest_5_minutes(_until)
      if finish <= start
        finish = start+300
      end
      intervals = ((finish - start) / _interval).round
      i = 1
      while i <= intervals do
        timestamps[start+(i*300)] = false
        i += 1
      end 
    end
    #Create machine nic readings
    readings_from_stats(stats,timestamps)
  end

  def readings_from_stats(performance_metrics, timestamps)
    # Helper Method for creating readings objects.
    result = []
    if performance_metrics.is_a? (RbVmomi::VIM::PerfEntityMetric)
      performance_metrics.sampleInfo.each_with_index.map do |x,i|
        if !performance_metrics.value.empty?
          receive_metric =  "148.#{key}"
          transmit_metric = "149.#{key}"
          metric_readings = Hash[performance_metrics.value.map{|s| ["#{s.id.counterId}.#{s.id.instance}",s.value]}]
          result << MachineNicReading.new(
              date_time:  x.timestamp,
              receive:    metric_readings[receive_metric].nil? ? 0 : metric_readings[receive_metric][i] == -1 ? 0 : metric_readings[receive_metric][i],
              transmit:   metric_readings[transmit_metric].nil? ? 0 : metric_readings[transmit_metric][i] == -1 ? 0 : metric_readings[transmit_metric][i]
          )
        timestamps[x.timestamp] = true
        end
      end
    end
    timestamps.keys.each do | timestamp |
      if !timestamps[timestamp]
        result <<  MachineNicReading.new(
            receive:  0,
            transmit: 0,
            date_time: timestamp.iso8601.to_s
        )
      end
    end
    result
  end
end