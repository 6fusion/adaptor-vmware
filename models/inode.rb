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

  def networks
    self.vmware_api_adaptor.networks.map { |network| Network.new(network) }
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

  def release_version
    if File.exists?('/var/6fusion/adaptor-vmware/current/VERSION')
      File.read('/var/6fusion/adaptor-vmware/current/VERSION').chomp
    else
      "#{`git branch --no-color 2> /dev/null`.chomp.split("\n").grep(/^[*]/).first[/(\S+)$/, 1]} #{`git rev-parse HEAD`.chomp}"
    end
  end

  def close_connection
    vmware_api_adaptor.disconnect if vmware_api_adaptor
  end

   # used by #save to serialize iNode configurations
  # @param [Hash] options -- ignored
  # @return [String] JSON encoded string
  def to_json(options={ })
    Rabl::Renderer.json(self, 'inodes/create')
  end
end
