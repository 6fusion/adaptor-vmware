
require 'lib/unix_proxy_environment'

class INode < Base::INode
  attr_reader :uuid, :session, :host_ip_address, :user, :password

  def open_session
    begin
      # Connect to vCenter if the session is not already established
      logger.info("INode.open_session")        
      # proxy_uri = SixFusion::find_proxy('http_proxy',@host_ip_address)
      # if proxy_uri
      #   logger.info("RvVmomi proxy used "+proxy_uri.host.to_s+":"+proxy_uri.port.to_s)
      #   @session ||= RbVmomi::VIM.connect(:host => @host_ip_address, :user => @user, :password => @password, :insecure => true, :proxyHost => proxy_uri.host, :proxyPort => proxy_uri.port)
      # else
      #   logger.info("RbVmomi no proxy used")
      #   @session ||= RbVmomi::VIM.connect(:host => @host_ip_address, :user => @user, :password => @password, :insecure => true)
      # end
      if (Time.now.utc - @session.serviceInstance.CurrentTime).abs > 300
        raise Exceptions::Forbidden.new("Local time is more than 5 minute out of sync with the hypervisor's time. Local time is #{Time.now.utc} and the hypervisor's time is #{@session.serviceInstance.CurrentTime}.")
      end
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable.new(e.message)
    end
  end

  def close_session
    logger.info("INode.close_session")
    begin
      unless @session.nil?
        @session.close
        @session = nil
      end

    rescue RbVmomi::Fault => e
      raise Exceptions::Unrecoverable.new(e.message)

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
