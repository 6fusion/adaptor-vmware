require 'time'

class Time
  def self.hour_ago
    now - 3600
  end
  def self.yesterday
    now - 86400
  end

  def to_datetime
    # Convert seconds + microseconds into a fractional number of seconds
    seconds = sec + Rational(usec, 10**6)

    # Convert a UTC offset measured in minutes to one measured in a
    # fraction of a day.
    offset = Rational(utc_offset, 60 * 60 * 24)
    DateTime.new(year, month, day, hour, min, seconds, offset)
  end

  def self.round_to_highest_5_minutes(_time)
    _offset = 0
    if ((_time.min / 5).round * 5) < _time.min
      _offset = 300
    end
    _rounded = Time.new(_time.year, _time.month, _time.day, _time.hour, ((_time.min / 5).round * 5), 0, "+00:00")
    _rounded += _offset
    _rounded
  end

  def self.round_to_lowest_5_minutes(_time)
    _offset = 0
    if ((_time.min / 5).round * 5) < _time.min
      _offset = 300
    end
    _rounded = Time.new(_time.year, _time.month, _time.day, _time.hour, ((_time.min / 5).round * 5), 0, "+00:00")
    _rounded -= _offset
    _rounded
  end
end

RbVmomi::VIM::PerformanceManager
class RbVmomi::VIM::PerformanceManager

  #This is used to cache the available metrics for each session
  def perfcounter_cached
    @perfcounter ||= perfCounter
  end

  # This is used to search for metrics by name
  def perfcounter_hash
    @perfcounter_hash ||= Hash[perfcounter_cached.map{|x| [x.name, x]}]
  end

  def perfcounter_idhash
    @perfcounter_idhash ||= Hash[perfcounter_cached.map{|x| [x.key, x]}]
  end

  # This method is used to retrieve the metrics for a list of virtual machines
  def retrieve_stats (objects, metrics, interval,start_time,end_time)
    logger.info(start_time.to_s)
    logger.info(end_time.to_s)
    metric_ids = metrics.map do |x, y|
      RbVmomi::VIM::PerfMetricId(:counterId => perfcounter_hash[x].key, :instance => y)
    end

    # Create a query spec object for each virtual machine you want to collect performance data
    query_specs = objects.map do |obj|
      RbVmomi::VIM::PerfQuerySpec({
                                      :entity => obj,
                                      :format => "normal",
                                      :metricId => metric_ids,
                                      :intervalId => interval,
                                      :startTime => start_time,
                                      :endTime => end_time
                                  })
    end

    # Send all query spec objects as an array to the QueryPerf method on the Performance Manager object
    QueryPerf(:querySpec => query_specs)
  end
end