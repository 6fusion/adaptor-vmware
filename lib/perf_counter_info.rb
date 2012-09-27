RbVmomi::VIM::PerfCounterInfo
class RbVmomi::VIM::PerfCounterInfo
  def name
    "#{groupInfo.key}.#{nameInfo.key}.#{rollupType}"
  end
end