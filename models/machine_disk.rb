require 'time'
# @api public
class MachineDisk < Base::MachineDisk
  attr_accessor :vm,
                :stats,
                :key,
                :vdisk,
                :vdisk_files

  KB = 1024
  MB = 1024**2
  GB = 1024**3
  TB = 1024**4

  def readings(inode, _interval = 300, _since = 5.minutes.ago.utc, _until = Time.now.utc)
    logger.info('machine_disk.readings')

    #Create list of timestamps
    timestamps = { }
    if _since < Time.now.utc
      start  = _since.round(5.minutes).utc
      finish = _until.floor(5.minutes).utc
      if finish <= start
        finish = start+300
      end
      intervals  = ((finish - start) / _interval).round
      timestamps = { }
      i          = 1
      while i <= intervals do
        timestamps[start+(i*300)] = false
        i                         += 1
      end
    end

    #Create machine disk readings from stats variable
    result = []
    # performance_manager = inode.session.serviceContent.perfManager
    # if stats.is_a?(RbVmomi::VIM::PerfEntityMetric)
    #   stats.sampleInfo.each_with_index.map do |x, i|
    #     if stats.value.empty?.eql?(false)
    #       read_metric = "#{performance_manager.perfcounter_hash["virtualDisk.read.average"].key}.scsi#{vdisk.controllerKey-1000}:#{vdisk.unitNumber}"
    #       write_metric = "#{performance_manager.perfcounter_hash["virtualDisk.write.average"].key}.scsi#{vdisk.controllerKey-1000}:#{vdisk.unitNumber}"
    #       metric_readings = Hash[stats.value.map { |s| ["#{s.id.counterId}.#{s.id.instance}", s.value] }]
    #       logger.debug("Disk Usage "+vdisk_files.map(&:size).inject(0, :+).to_s)
    #       result << MachineDiskReading.new({ :usage     => vdisk_files.map(&:size).inject(0, :+),
    #                                          :read      => metric_readings[read_metric].nil? ? 0 : metric_readings[read_metric][i] == -1 ? 0 : metric_readings[read_metric][i],
    #                                          :write     => metric_readings[write_metric].nil? ? 0 : metric_readings[write_metric][i] == -1 ? 0 : metric_readings[write_metric][i],
    #                                          :date_time => x.timestamp })
    #       timestamps[x.timestamp] = true
    #     end
    #   end
    # end
    # timestamps.keys.each do |timestamp|
    #   if timestamps[timestamp].eql?(false)
    #     result << MachineDiskReading.new(
    #       {
    #         :usage     => vdisk_files.map(&:size).inject(0, :+) / GB,
    #         :read      => 0,
    #         :write     => 0,
    #         :date_time => timestamp.iso8601.to_s
    #       }
    #     )
    #   end
    # end
    result
  end

end