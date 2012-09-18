class INode < Base::INode
  attr_reader :uuid, :session, :host_ip_address, :user, :password

  def open_session
    begin
      # Connect to vCenter if the session is not already established
      @session ||= RbVmomi::VIM.connect :host => @host_ip_address, :user => @user, :password => @password, :insecure => true
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable.new(e.message)
    end
  end

  def close_session
    begin
      unless @session.nil?
        @session.close
        @session = nil
      end

    rescue RbVmomi::Fault => e
      raise Exceptions::Forbidden.new(e.message)

    rescue => e
      logger.error(e.message)
      raise exceptions::Unrecoverable
    end
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
end
