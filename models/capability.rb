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
    machines
    machines_readings
    machine
    machine_readings
    add
    start
    stop
    restart
    force_stop
    force_restart
    diagnostics
    delete
    )
  def self.all(inode)
    logger.info('Capability.all')
    SUPPORTED_CAPABILITIES.map do |capability|
      Capability.new(:name => capability)
    end
  end
end