
require 'java'
Dir['lib/java/**/*.jar'].each do |jar|
  $CLASSPATH << jar
  require jar
end
$CLASSPATH << "#{PADRINO_ROOT}/lib/java"
java_import "com.sixfusion.VMwareAdaptor"
java_import "java.util.ArrayList"
java_import "com.vmware.vim25.InvalidLogin"

class INode < Base::INode
  attr_reader :uuid, :session, :host_ip_address, :user, :password, :vmware_adaptor

  def about
    # Connect to vCenter if the session is not already established
    logger.info("INode.open_session")        
    @vmware_adaptor = VMwareAdaptor.new("https://#{@host_ip_address}/sdk", @user, @password)
    @vmware_adaptor.gatherVirtualMachines
    @vmware_adaptor.getAboutInfo.to_hash
  end

  def virtual_machines
    # Connect to vCenter if the session is not already established
    logger.info("INode.open_session")        
    @vmware_adaptor = VMwareAdaptor.new("https://#{@host_ip_address}/sdk", @user, @password)
    @vmware_adaptor.gatherVirtualMachines
    @vmware_adaptor.json
  end

  def statistics_levels 
    # Connect to vCenter if the session is not already established
    logger.info("INode.open_session")        
    @vmware_adaptor = VMwareAdaptor.new("https://#{@host_ip_address}/sdk", @user, @password)
    @vmware_adaptor.gatherVirtualMachines
    rList = []
    arrList = vmware_adaptor.getStatisticLevels
    arrList.each do | statistics_level |
      rList << statistics_level.to_hash
    end
    rList
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
    if @vmware_adaptor
      @vmware_adaptor.close
    end
  end
end
