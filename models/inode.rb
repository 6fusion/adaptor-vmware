
require 'java'
Dir['lib/java/**/*.jar'].each do |jar|
  $CLASSPATH << jar
  require jar
end
$CLASSPATH << "#{PADRINO_ROOT}/lib/java"
java_import "VMwareInventory"
java_import "java.util.ArrayList"
java_import "com.vmware.vim25.InvalidLogin"

class INode < Base::INode
  attr_reader :uuid, :session, :host_ip_address, :user, :password

  def about
    begin
      # Connect to vCenter if the session is not already established
      logger.info("INode.open_session")        
      vm_inventory = VMwareInventory.new("https://#{@host_ip_address}/sdk", @user, @password)
      vm_inventory.gatherVirtualMachines
      vm_inventory.getAboutInfo.to_hash
    rescue InvalidLogin => e
      raise Exceptions::Forbidden, "Invalid Login" 
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable, e.to_s
    ensure
      unless vm_inventory.nil?
        self.close_vm_inventory(vm_inventory)
      end
    end
  end

  def statistics_levels 
    begin
      # Connect to vCenter if the session is not already established
      logger.info("INode.open_session")        
      vm_inventory = VMwareInventory.new("https://#{@host_ip_address}/sdk", @user, @password)
      vm_inventory.gatherVirtualMachines
      rList = []
      arrList = vm_inventory.getStatisticLevels
      arrList.each do | statistics_level |
        rList << statistics_level.to_hash
      end
      rList
    rescue InvalidLogin => e
      raise Exceptions::Forbidden, "Invalid Login" 
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable, e.to_s
    ensure
      self.close_vm_inventory(vm_inventory)
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

  def close_vm_inventory(vm_inventory)
    if vm_inventory
      vm_inventory.close
    end
  end
end
