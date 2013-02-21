require 'java'
Dir['lib/java/**/*.jar'].each do |jar|
  $CLASSPATH << jar
  logger.info("#{jar}")
  require jar
end
$CLASSPATH << "#{PADRINO_ROOT}/lib/java"
java_import "java.net.URL"
# java_import "com.sixfusion.VMwareAdaptor"
# java_import "java.util.ArrayList"
# java_import "com.vmware.vim25.InvalidLogin"
java_import "java.rmi.RemoteException"

module VIJavaUtil
  include_package "com.vmware.vim25.mo.util"
end
module VIJava
  include_package "com.vmware.vim25.mo"
end
module Vim
  include_package "com.vmware.vim25"
end

class VmwareApiAdaptor
	attr_accessor :inode

	def initialize(inode)
		self.inode = inode
	end

	# --------------------------------------------------------
	# Connection managment
	# --------------------------------------------------------

	def connection
		@connection ||= self.connect(inode.host_ip_address, inode.user, inode.password)
	end

	def connected?
    @connection.present?
  end

  # Manage a connection to a Vmware host.
  # @param _host [String]
  # @param _user [String]
  # @param _password [String]
  # @return [VIJava, VIJava::ServiceInstance]
  # @yield [VIJava, VIJava::ServiceInstance]
  def connect(_host, _user, _password)
  	# TODO: retry logic, exception handling
  	disconnect
  	retry_count = 0
  	# begin
  		retry_count += 1
  		@connection = VIJava::ServiceInstance.new(URL.new("https://#{_host}/sdk"), _user, _password, true)
  	# rescue java.rmi.RemoteException
  	# 	java.rmi.RemoteException => exception
  	# 	logger.error "Unable to connect to #{_host} with #{_user} try ##{retry_count}: #{exception}"
  	# 	if retry_count < 5
   #      sleep 1
   #      retry
   #    else
   #      raise exception
   #    end
  	# end

  	return @connection
  end

	def disconnect
		if connected?
			logger.info "Disconnecting..."
			@connection.get_server_connection.logout
		end
		@connection = nil
	end

	def root_folder
		self.connection.get_root_folder
	end

	# --------------------------------------------------------
	# Hosts
	# --------------------------------------------------------

	def hosts
		logger.info("vmware_api_adaptor#hosts");
		hosts = VIJava::InventoryNavigator.new(self.root_folder).search_managed_entities("HostSystem");
	end

 	# --------------------------------------------------------
	# Virtual Machines
	# --------------------------------------------------------

	VM_PROPERTIES = %w(
    name
	  config.hardware.device
	  guest.toolsStatus
	  guest.guestId
	  guest.net
	  config.uuid
	  config.template
	  layoutEx.disk
	  layoutEx.file
	  runtime.powerState
	  runtime.host
	  config.hardware.memoryMB
	  config.hardware.numCPU
	)

	def virtual_machines()
		logger.info("vmware_api_adaptor#virtual_machines");
    virtual_machines = VIJava::InventoryNavigator.new(self.root_folder).search_managed_entities("VirtualMachine");
	end

	def virtual_machine_properties()
		logger.info("vmware_api_adaptor.virtual_machine_properties")
		logger.info(VM_PROPERTIES)
		temp = VIJavaUtil::PropertyCollectorUtil.retrieve_properties(self.virtual_machines, "VirtualMachine", VM_PROPERTIES.to_java(:string))
	end

	def find_vm_by_uuid(_uuid)
    logger.info("vmware_api_adaptor#find_vm_by_uuid");
    vm = self.connection.get_search_index.find_by_uuid(nil, _uuid, true, false);
    # if (vm == null) {
    #   logger.info("Machine UUID "+uuid+" not found");
    #   return null;
    # }
    # vms[0] = vm;
    # gatherProperties(vms);
    return vm
    logger.info("Exiting VMwareAdaptor.findByUuid(String uuid)");
    # return vmMap.get(vm.getMOR().get_value().toString());
  end

  def start(_uuid)
		logger.info("vmware_api_adaptor.start")
  	machine = find_vm_by_uuid(_uuid)
  	machine.power_on_vm_task(nil)
  end

  def stop(_uuid)
  	logger.info("vmware_api_adaptor.stop")
    machine = find_vm_by_uuid(_uuid)
    machine.power_off_vm_task
  end

  def restart(_uuid)
  	begin
	  	logger.info("vmware_api_adaptor.restart")
	    machine = find_vm_by_uuid(_uuid)
	    machine.reboot_guest
    rescue Java::ComVmwareVim25::ToolsUnavailable => e
    	logger.warn("Invalid #{e.cause.shortDescription}")
      raise Exceptions::MethodNotAllowed.new("Cannot Complete Requested Action: #{e.cause.shortDescription}")
    end
  end

end