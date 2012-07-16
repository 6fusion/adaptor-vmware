# @api public
class MachineDisk < Base::MachineDisk
  attr_accessor :vm,:key
  # This is where you would call your cloud service and
  # find a specific machine's disk's readings.
  # This request should support since (start_date) and until (end_date)
  # 
  # @param [INode] i_node iNode instance that defines where the action is to take place
  # @param [Time] _since The beginning date/time for the requested readings
  # @param [Time] _until The ending date/time for the requested readings
  # @return [Machine]
  def readings(i_node, _since = Time.now.utc.yesterday, _until = Time.now.utc)
    logger.info('machine_disk.readings')

    vim = RbVmomi::VIM.connect :host => i_node.connection, :user => i_node.credentials_hash["username"], :password => i_node.credentials_hash["password"] , :insecure => true
    pm = vim.serviceContent.perfManager
    vms = [vm]
    metrics = {"virtualDisk.read.average" => "*","virtualDisk.write.average" => "*"}

    # Collects Performance information
    stats = pm.retrieve_stats(vms,metrics,300,_since,_until)

    readings = Array.new
    stats.each do |p|
      if p.entity == self.vm
        for f in 0..p.sampleInfo.length - 1
          reading = MachineDiskReading.new(
              usage: 32*1024*1024,
              read:  p.value[0].value[f].to_s,
              write: p.value[1].value[f].to_s
          )
          readings << reading
        end
      end
    end

    readings
  end
end