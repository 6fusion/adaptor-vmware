object @machine
attributes :uuid,
           :external_vm_id,
           :external_host_id,
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
attribute :name => :virtual_name

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
  attributes :uuid, :network_uuid, :name, :mac_address, :ip_address

  node :readings do |r|
    r.readings(@inode, _interval, _since, _until).map do |r|
      {
        :date_time => r.date_time,
        :receive => r.receive,
        :transmit => r.transmit
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