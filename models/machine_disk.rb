# @api public
class MachineDisk < Base::MachineDisk
  attr_accessor :vm,
                :stats,
                :key

  def readings(inode, _interval = 300, _since = Time.now.utc - 1800, _until = Time.now.utc)
    logger.info('machine_disk.readings')

    #Create machine disk readings
    readings_from_stats(stats)
  end

  def readings_from_stats(performance_metrics)
    # Helper Method for creating readings objects.
    performance_metrics.sampleInfo.each_with_index.map do |x,i|
      if performance_metrics.value.empty?
        MachineDiskReading.new(
            usage: 32,
            read:  0,
            write: 0
        )
      else
        metric_readings = Hash[performance_metrics.value.map{|s| ["#{s.id.counterId}.#{s.id.instance}",s.value]}]
        MachineDiskReading.new(
            usage: 32,
            read:  metric_readings["173.scsi0:0"].nil? ? 0 : metric_readings["173.scsi0:0"][i] == -1 ? 0 : metric_readings["173.scsi0:0"][i].to_s,
            write: metric_readings["174.scsi0:0"].nil? ? 0 : metric_readings["174.scsi0:0"][i] == -1 ? 0 : metric_readings["174.scsi0:0"][i].to_s
        )
      end
    end
  end
end