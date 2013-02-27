# require 'java'
# Dir['lib/java/**/*.jar'].each do |jar|
#   $CLASSPATH << jar
#   logger.info("#{jar}")
#   require jar
# end
# $CLASSPATH << "#{PADRINO_ROOT}/lib/java"

class INode < Base::INode
  attr_accessor :vmware_api_adaptor
  attr_reader :uuid, :session, :host_ip_address, :user, :password, :vmware_adaptor

  def initialize(attributes)
    super
    self.vmware_api_adaptor = VmwareApiAdaptor.new(self)
  end

  def connection
    self.hypervisor.connection
  end

  def capabilities
    Capability.all(uuid)
  end

  def hypervisor
    self.vmware_api_adaptor
  end

  def about
    logger.info("inode.about")
    vmware_api_adaptor.get_about_info
  end

  def virtual_machines
    logger.info("inode.virtual_machines")
    vmware_api_adaptor.virtual_machines
  end

  def statistics_levels
    logger.info("INode.statistics_levels")
    vmware_api_adaptor.get_statistic_levels
  end

  def self.find_by_uuid(uuid)
    logger.info("INode.find_by_uuid(#{uuid})")

    super
  end

  def update(uuid, params)
    logger.info("INode.update(#{uuid})")

    super
  end

  def save(uuid)
    logger.info("INode.save(#{uuid})")

    super
  end

  def delete(uuid)
    logger.info("INode.delete(#{uuid})")

    super
  end

  def close_connection
    vmware_api_adaptor.disconnect if vmware_api_adaptor
  end
end
