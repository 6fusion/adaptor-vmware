class MachineNic < Base::MachineNic
  attr_accessor :vm,
    :stats,
    :key,
    :vnic

  def readings(inode, _interval = 300, _since = 10.minutes.ago.utc, _until = 5.minutes.ago.utc)
    #logger.info('machine_nic.readings')
    #Create machine nic readings
    result = []
    unless @stats.nil?
      stats.keys.each do |timestamp|
        metrics = @stats[timestamp]
        receive_metric =  "net.received.average.#{key}"
        transmit_metric = "net.transmitted.average.#{key}"
        # logger.debug(receive_metric)
        # logger.debug(metrics.keys)
        # logger.debug(metrics[receive_metric])
        result << MachineNicReading.new({
                                          :receive      => metrics[receive_metric].nil? ? 0 : metrics[receive_metric] == -1 ? 0 : metrics[receive_metric],
                                          :transmit     => metrics[transmit_metric].nil? ? 0 : metrics[transmit_metric] == -1 ? 0 : metrics[transmit_metric],
        :date_time => timestamp})
      end
    end
    result
  end

end
