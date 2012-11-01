class MachineNic < Base::MachineNic
  attr_accessor :vm,
                :stats,
                :key,
                :vnic

  def readings(inode, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    logger.info('machine_nic.readings')

    #Create list of timestamps
    timestamps = {}
    if _since < Time.now.utc
      start = _since.round(5.minutes).utc
      finish = _until.floor(5.minutes).utc
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
    result = []
    performance_manager = inode.session.serviceContent.perfManager
    if stats.is_a?(RbVmomi::VIM::PerfEntityMetric)
      stats.sampleInfo.each_with_index.map do |x,i|
        if stats.value.empty?.eql?(false)
          receive_metric =  "#{performance_manager.perfcounter_hash["net.received.average"].key}.#{key}"
          transmit_metric = "#{performance_manager.perfcounter_hash["net.transmitted.average"].key}.#{key}"
          metric_readings = Hash[stats.value.map{|s| ["#{s.id.counterId}.#{s.id.instance}",s.value]}]
          result << MachineNicReading.new(
              :date_time => x.timestamp,
              :receive => metric_readings[receive_metric].nil? ? 0 : metric_readings[receive_metric][i] == -1 ? 0 : metric_readings[receive_metric][i],
              :transmit => metric_readings[transmit_metric].nil? ? 0 : metric_readings[transmit_metric][i] == -1 ? 0 : metric_readings[transmit_metric][i]
          )
          timestamps[x.timestamp] = true
        end
      end
    end
    timestamps.keys.each do | timestamp |
      if timestamps[timestamp].eql?(false)
        result <<  MachineNicReading.new(
            :receive => 0,
            :transmit => 0,
            :date_time => timestamp.iso8601.to_s
        )
      end
    end
    result
  end

end