class Capability < Base::Capability

  SUPPORTED_CAPABILITIES = %w(guest_inventory guest_metering guest_state host_state create)

  def self.all(inode)
    logger.info('Capability.all')
    SUPPORTED_CAPABILITIES.map do |capability|
      Capability.new(name: capability)
    end
  end
end
