# Do not modify this file
collection @machines

attributes :uuid,
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

child :disks => :disks do
  attributes :uuid, :name, :maximum_size, :type, :thin

end
child :nics => :nics do
  attributes :uuid, :name, :mac_address, :ip_address
end
