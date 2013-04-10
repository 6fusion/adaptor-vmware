attribute :uuid
attribute :release_version
attribute :host_ip_address

child :capabilities => :capabilities do
  attribute :name
end
child :networks => :networks do
	attribute :moref_id => :uuid
  attribute :name => :discovered_name
  attribute :is_accessible
  attribute :ip_pool_name
end
node :infrastructure_node_data_stores_attributes do |inode|
	inode.datastores
end