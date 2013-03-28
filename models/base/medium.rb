# @api public
# This class file should not be modified if you don't understand what you are doing.
class Base::MediaStore < Main
  # TODO: Figure out what needs to go here
  # attr_accessor :unknown

  def self.parse_ovf(_ovf_location)
    # get ovf xml
    ovf_xml = IO.read(_ovf_location)

    # parse ovf
    parse_params = Vim::OvfParseDescriptorParams.new()
    parse_params.set_locale("US")
    parse_params.set_deployment_option("")
    ovf_parse_result = ovf_manager.parseDescriptor(ovf_xml, parse_params)

    # figure out nic details
    ovf_nic = ovf_parse_result.get_network.each do |nic|
      # TODO: Create an array of nics for return to console
      logger.info("nic name: #{nic.get_name}")
    end

    # TODO: figure out disk details

    # TODO: figure out memory defailts

    # TODO: Figure out what the return object looks like
    # return self.new({ local_path: _local_mount_path, remote_path: _remote_mount_path })
  end
end
