# @api public
# This class file should not be modified if you don't understand what you are doing.
class Base::Medium < Main
  # TODO: Figure out what needs to go here
  # attr_accessor :unknown

  def self.parse_ovf(inode, _ovf_location)
    adaptor = inode.vmware_api_adaptor
    ovf_manager = adaptor.connection.get_ovf_manager

    # get ovf xml
    ovf_xml = IO.read(_ovf_location)

    # parse ovf
    parse_params = Vim::OvfParseDescriptorParams.new()
    parse_params.set_locale("US")
    parse_params.set_deployment_option("")
    ovf_parse_result = ovf_manager.parseDescriptor(ovf_xml, parse_params)

    ovf_obj = {}
    # figure out nic details
    ovf_obj[:nic_attributes] = ovf_parse_result.get_network.collect { |nic| {name: nic.get_name, description: nic.get_description} }

    # TODO: figure out disk details
    logger.info(ovf_obj.inspect)

    # TODO: figure out memory defailts

    # TODO: Figure out what the return object looks like
    # return self.new({ local_path: _local_mount_path, remote_path: _remote_mount_path })
    ovf_obj
  end
end
