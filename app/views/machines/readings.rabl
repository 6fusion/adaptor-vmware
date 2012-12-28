collection @machines if @machines.present?

#node(:total) {|m| @machines.total_count }
#node(:total_pages) {|m| @machines.num_pages }

object @machine if @machine.present?
attributes :uuid,
           :external_vm_id,
           :external_host_id,
           :name,
           :cpu_count,
           :cpu_speed,
           :maximum_memory,
           :system ,
           :guest_agent,
           :power_state,
           :hostname,
           :data_center_uuid,
           :description,
           :host_uuid

_interval = params[:interval].blank? ? 300 : params[:interval]
_since = params[:since].blank? ? 5.minutes.ago.utc : Time.iso8601(params[:since])
_until = params[:until].blank? ? Time.now.utc : Time.iso8601(params[:until])

child :disks => :disks do
  attributes :uuid, :name, :maximum_size, :type, :thin

  node :readings do |r|
    r.readings(@inode, _interval, _since, _until).map do |r|
      {
        :usage => r.usage,
        :read => r.read,
        :write => r.write,
        :date_time => r.date_time
      }
    end
  end
end

child :nics => :nics do
  attributes :uuid, :name, :mac_address, :ip_address

  node :readings do |r|
    r.readings(@inode, _interval, _since, _until).map do |r|
      {
        :date_time => r.date_time,
        :receive => r.receive * 8,
        :transmit => r.transmit * 8
      }
    end
  end
end

node :readings do |o|
  o.readings(_interval, _since, _until).map do |r|
    {
      :interval => r.interval,
      :date_time => r.date_time,
      :cpu_usage => r.cpu_usage,
      :memory_bytes => r.memory_bytes
    }
  end
end