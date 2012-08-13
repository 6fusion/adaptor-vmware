class Inode < Base::Inode
  attr_reader :session

  def open_session
    begin
      #Converts the credentials in "username|password" format to a hash
      credential_items = @credentials.split "|"

      # Connect to vCenter if the session is not already established
      @session ||= RbVmomi::VIM.connect :host => @connection, :user => credential_items[0], :password => credential_items[1] , :insecure => true
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable
    end
  end

  def close_session
    begin
      unless @session.nil?
        @session.close
        @session = nil
      end
    rescue => e
      logger.error(e.message)
      raise exceptions::Unrecoverable
    end
  end

  def self.find_by_uuid(uuid)
    logger.info("Inode.find_by_uuid(#{uuid})")

    super
  end

  def update(uuid, params)
    logger.info("Inode.update(#{uuid})")

    super
  end

  def save(uuid)
    logger.info("Inode.save(#{uuid})")

    super
  end

  def delete(uuid)
    logger.info("Inode.delete(#{uuid})")

    super
  end
end