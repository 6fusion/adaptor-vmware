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

    #Create machine disk readings
    readings_from_stats(stats)
  end

  def readings_from_stats(performance_metrics)
    # Helper Method for creating readings objects.
    if performance_metrics.is_a? (RbVmomi::VIM::PerfEntityMetric)
      performance_metrics.sampleInfo.each_with_index.map do |x,i|
        if performance_metrics.value.empty?
          MachineDiskReading.new(
              usage: vdisk_files.map(&:size).inject(0, :+) / GB,
              read:  0,
              write: 0,
              date_time: x.timestamp
          )
        else
          read_metric = "174.scsi#{vdisk.controllerKey-1000}:#{vdisk.unitNumber}"
          write_metric = "174.scsi#{vdisk.controllerKey-1000}:#{vdisk.unitNumber}"
          metric_readings = Hash[performance_metrics.value.map{|s| ["#{s.id.counterId}.#{s.id.instance}",s.value]}]
          MachineDiskReading.new(
              usage: vdisk_files.map(&:size).inject(0, :+) / GB,
              read: metric_readings[read_metric].nil? ? 0 : metric_readings[read_metric][i] == -1 ? 0 : metric_readings[read_metric][i],
              write: metric_readings[write_metric].nil? ? 0 : metric_readings[write_metric][i] == -1 ? 0 : metric_readings[write_metric][i],
              date_time: x.timestamp
          )
        end
      end
    else
      Array.new
    end
  end
end