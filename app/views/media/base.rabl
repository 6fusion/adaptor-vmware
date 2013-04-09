# TODO: Figure out what the response looks like
# attributes :annotation,
#     :approximate_download_size,
#     :approximate_flat_deployment_size,
#     :approximate_sparse_deployment_size,
#     :default_deployment_option,
#     :name

node :network_interfaces_attributes do
	@medium.network_interfaces_attributes.map { |e| { :name => e[:name] } }
end

# node :ip_protocols do
# 	@medium.ip_protocols.map { |e| e[:assignment] }
# end
# node :ip_allocation_scheme do
# 	@medium.ip_allocation_scheme.map { |e| e[:allocation_scheme] }
# end

# node :warnings do
# 	@medium.warnings.map { |e| e[:description] }
# end

# node :errors do
# 	@medium.errors.map { |e| e[:description] }
# end