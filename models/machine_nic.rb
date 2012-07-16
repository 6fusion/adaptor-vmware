# @api public
class MachineNic < Base::MachineNic
  attr_accessor :vm,:key
  # This is where you would call your cloud service and
  # find a specific machine's nic's readings.
  # This request should support since (start_date) and until (end_date)
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @param [Time] _since The beginning date/time for the requested readings
  # @param [Time] _until The ending date/time for the requested readings
  # @return [Machine]
  def readings(i_node, _since = Time.now.utc.beginning_of_month, _until = Time.now.utc)
    logger.info('MachineNic.readings')

    vim = RbVmomi::VIM.connect :host => i_node.connection, :user => i_node.credentials_hash["username"], :password => i_node.credentials_hash["password"] , :insecure => true
    pm = vim.serviceContent.perfManager
    vms = [vm]
    metrics = {"net.received.average" => "#{key}","net.transmitted.average" => "#{key}"}

    # Collects Performance information
    stats = pm.retrieve_stats(vms,metrics,20,12,Time.now - 300 * 12)

    readings = Array.new
    stats.each do |p|
      if p.entity == self.vm
        for f in 0..p.sampleInfo.length - 1
          reading = MachineNicReading.new(
              receive:    p.value[0].value[f].to_s,
              transmit:   p.value[1].value[f].to_s
          )
          readings << reading
        end
      end
    end

    readings
  end
end