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