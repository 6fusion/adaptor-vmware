# @api public
# This class file should not be modified if you don't understand what you are doing.
class Base::Medium < Main
  # TODO: Figure out what needs to go here
  attr_accessor :annotation,
    :approximate_download_size,
    :approximate_flat_deployment_size,
    :approximate_sparse_deployment_size,
    :default_deployment_option,
    :errors,
    :name,
    :network_interfaces,
    :ovf_file_location,
    :warnings,
    :ip_allocation_scheme,
    :ip_protocols

  def self.parse_ovf(inode, _ovf_location)
    logger.info("medium.parse_ovf")
    adaptor = inode.vmware_api_adaptor
    ovf_manager = adaptor.connection.get_ovf_manager

    # get ovf xml
    ovf_xml = IO.read(_ovf_location)

    # parse ovf
    parse_params = Vim::OvfParseDescriptorParams.new()
    parse_params.set_locale("US")
    parse_params.set_deployment_option("")
    ovf_parse_result = ovf_manager.parseDescriptor(ovf_xml, parse_params)

    ovf_import_result = {
        ovf_file_location: _ovf_location,
        annotation: ovf_parse_result.get_annotation,
        name: ovf_parse_result.get_default_entity_name,
        approximate_download_size: ovf_parse_result.get_approximate_download_size,
        approximate_flat_deployment_size: ovf_parse_result.get_approximate_flat_deployment_size,
        approximate_sparse_deployment_size: ovf_parse_result.get_approximate_sparse_deployment_size,
        default_deployment_option: ovf_parse_result.get_default_deployment_option
    }

    # ovf_parse_result.get_annotated_ost is worthless, don't explore it...seriously, i warned you -ag

    # Build errors and warnings
    ovf_import_result[:errors] = (ovf_parse_result.get_error ? ovf_parse_result.get_error.map { |e| { description: e.get_localized_message } } : {})
    ovf_import_result[:warnings] = (ovf_parse_result.get_warning ? ovf_parse_result.get_warning.map { |w| { description: w.get_localized_message } } : {})

    # figure out nic details
    ovf_import_result[:network_interfaces] = (ovf_parse_result.get_network ? ovf_parse_result.get_network.collect { |nic| {name: nic.get_name, description: nic.get_description} } : {})
    ovf_import_result[:ip_protocols] = (ovf_parse_result.get_ip_protocols ? ovf_parse_result.get_ip_protocols.collect { |na| { assignment: na } } : {})
    ovf_import_result[:ip_allocation_scheme] = (ovf_parse_result.get_ip_allocation_scheme ? ovf_parse_result.get_ip_allocation_scheme.collect { |scheme| { allocation_scheme: scheme } } : {})

    # TODO: figure out disk details
    # TODO: figure out memory defaults
    # TODO: Figure out what the return object looks like
    self.new(ovf_import_result)
  end

  private
  def self.log_available_methods(_object, _regex=nil, _execute_it=false)
    logger.info("_object class type: #{_object.get_class}")

    methods = _object.methods
    methods = methods.grep(_regex) if _regex.present?

    methods.each do |method|
      logger.info "Method: #{method}"
      logger.info "*** Result: #{_object.send(method)}" if _execute_it
    end
  end
end
