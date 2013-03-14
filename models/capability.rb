class Capability < Base::Capability

  # SUPPORTED_CAPABILITIES = %w(
  #   inode 
  #   machines 
  #   machines_readings 
  #   machine 
  #   machine_readings 
  #   start 
  #   stop 
  #   restart 
  #   force_stop 
  #   force_restart 
  #   delete
  #   )
  SUPPORTED_CAPABILITIES = %w(
    inode
    historical_readings
    machines 
    machines_readings 
    machine 
    machine_readings
    diagnostics 
    )
  def self.all(inode)
    logger.info('Capability.all')
    SUPPORTED_CAPABILITIES.map do |capability|
      Capability.new(:name => capability)
    end
  end

  def ==(other)
    other.to_s.eql?(name)
  end

  def to_s
    return name
  end
end
