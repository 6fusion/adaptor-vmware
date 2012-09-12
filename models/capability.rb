class Capability < Base::Capability

  SUPPORTED_CAPABILITIES = %w(machines,machines_readings,machine,start,stop,restart,force_stop,force_restart,delete)

  def self.all(inode)
    logger.info('Capability.all')
    SUPPORTED_CAPABILITIES.map do |capability|
      Capability.new(name: capability)
    end
  end
end
