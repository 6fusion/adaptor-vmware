class MachineNic < Base::MachineNic
  attr_accessor :vm,
                :stats,
                :key,
                :vnic

  def readings(inode, _interval = 300, _since = 10.minutes.ago.utc, _until = 5.minutes.ago.utc)
    #logger.info('machine_nic.readings')

    #Create list of timestamps
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

    #Create machine nic readings
    result = []
    if !@stats.nil? 
      stats.keys.each do |timestamp|
        # if @stats.key?(timestamp.utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z")
          # logger.info("found "+timestamp.utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z")
          metrics = @stats[timestamp]
          receive_metric =  "net.received.average.#{key}"
          transmit_metric = "net.transmitted.average.#{key}"
          # logger.debug(receive_metric)
          # logger.debug(metrics.keys)
          # logger.debug(metrics[receive_metric])
          result << MachineNicReading.new({ 
                                             :receive      => metrics.nil? ? 0 : metrics[receive_metric] == -1 ? 0 : metrics[receive_metric],
                                             :transmit     => metrics.nil? ? 0 : metrics[transmit_metric] == -1 ? 0 : metrics[transmit_metric],
                                             :date_time => timestamp})
        # else
        #   # logger.debug("missing "+timestamp.utc.strftime('%Y-%m-%dT%H:%M:%S')+".000Z "+@stats.to_s)
        #   result << MachineNicReading.new({ 
        #                            :receive      => 0,
        #                            :transmit     => 0,
        #                            :date_time => timestamp.iso8601.to_s })
        # end
      # else
      #   # logger.debug("stats is nil")
      #   result << MachineNicReading.new({ 
      #                              :receive      => 0,
      #                              :transmit     => 0,
      #                              :date_time => timestamp.iso8601.to_s })
      end
    end
    result
  end

end