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
    inode_delete
    machines
    machines_readings
    machines_readings_historical
    machine
    add
    start
    stop
    restart
    force_stop
    force_restart
    diagnostics
    delete
    media_store_add_mount
    media_store_delete_mount
    medium_parse
    medium_delete
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
