require 'time'
# @api public
class MachineDisk < Base::MachineDisk
  attr_accessor :stats,
    :usage,
    :key,
    :unit_number,
    :controller_key

  KB = 1024
  MB = 1024**2
  GB = 1024**3
  TB = 1024**4
  # def stats=(stats)
  #   logger.debug("Adding disk stats")
  #   @stats = stats
  # end

  def readings(inode, _interval = 300, _since = 10.minutes.ago.utc, _until = 5.minutes.utc)
    #logger.info('machine_disk.readings')

    #Create machine disk readings from stats variable
    result = []
    if !@stats.nil?
      stats.keys.each do |timestamp|
        metrics = @stats[timestamp]
        if @controller_key.eql?(1000)
          # SCSI controller
          # virtualDisk.write.average.scsi0:0
          read_metric = "virtualDisk.read.average.scsi#{@key-2000}:#{@unit_number}"
          write_metric = "virtualDisk.write.average.scsi#{@key-2000}:#{@unit_number}"
        elsif @controller_key.eql?(200)
          # IDE controller
          read_metric = "virtualDisk.read.average.ide#{@key-3000}:#{@unit_number}"
          write_metric = "virtualDisk.write.average.ide#{@key-3000}:#{@unit_number}"
        end
        # logger.debug(write_metric)
        # logger.debug(metrics.keys)
        result << MachineDiskReading.new({ :usage     => @usage / GB,
                                           :read      => metrics[read_metric].nil? ? 0 : metrics[read_metric] == -1 ? 0 : metrics[read_metric],
                                           :write     => metrics[write_metric].nil? ? 0 : metrics[write_metric] == -1 ? 0 : metrics[write_metric],
                                           :date_time => timestamp})

      end
    end
    result
  end

end
