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
  KB = 1024.0
  MB = 1024.0**2
  GB = 1024.0**3

	def initialize(inode)
		self.inode = inode
	end

	# --------------------------------------------------------
	# Connection management
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

  HOST_PROPERTIES = %w(
    name
    hardware.cpuInfo.hz
    hardware.memorySize
  )

	def hosts
		logger.info("vmware_api_adaptor.hosts");
		host_managed_objects = VIJava::InventoryNavigator.new(self.root_folder).search_managed_entities("HostSystem");
    host_properties = VIJavaUtil::PropertyCollectorUtil.retrieve_properties(host_managed_objects, "HostSystem", HOST_PROPERTIES.to_java(:string))

    # logger.info "\n\n"
    # logger.info host_properties.inspect
    # logger.info "\n\n"

    _hosts = []
    host_managed_objects.each do |h|
      prop_record = host_properties.select { |e| e["name"] == h.name }
      if prop_record.present?
        _hosts << {
          :host_mor => h,
          :host_id => h.get_mor.get_value,
          :name => prop_record.first["name"],
          :hz => prop_record.first["hardware.cpuInfo.hz"],
          :memorySize => prop_record.first["hardware.memorySize"],
        }
      end
    end

    return _hosts
	end

 	# --------------------------------------------------------
	# Virtual Machines
	# --------------------------------------------------------

	VM_PROPERTIES = %w(
    name
	  config.hardware.device
	  guest.toolsStatus
	  guest.guestId
    guest.guestFullName
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
    vms = VIJava::InventoryNavigator.new(self.root_folder).search_managed_entities("VirtualMachine");
    virtual_machines = gather_properties(vms)

    return virtual_machines
	end

	def gather_properties(vms)
		logger.info("vmware_api_adaptor.gather_properties")
    _hosts = self.hosts
		vms_with_properties = VIJavaUtil::PropertyCollectorUtil.retrieve_properties(vms, "VirtualMachine", VM_PROPERTIES.to_java(:string))

    virtual_machines_with_properties = []
    vms_with_properties.each do |vm|
      unless vm["config.template"]
        vm_managed_object = vms.select { |e| e.config.uuid == vm["config.uuid"] }.first
        vm_host = _hosts.select { |e| e[:host_id] == vm["runtime.host"].get_value }.first
        vm_properties_hash = {}

        vm_mor_id = vm_managed_object.get_mor.get_value.to_s
        vm_properties_hash["external_vm_id"] = vm_mor_id if vm_mor_id.present?
        vm_properties_hash["external_host_id"] =  vm["runtime.host"].get_value if vm["runtime.host"].get_value.present?
        vm_properties_hash["uuid"] = vm["config.uuid"] if vm["config.uuid"].present?
        vm_properties_hash["name"] = vm["name"] if vm["name"].present?
        vm_properties_hash["cpu_count"] = vm["config.hardware.numCPU"] if vm["config.hardware.numCPU"].present?
        vm_properties_hash["maximum_memory"] = vm["config.hardware.memoryMB"] if vm["config.hardware.memoryMB"].present?
        vm_properties_hash["power_state"] = vm["runtime.powerState"].to_s if vm["runtime.powerState"].present?
        vm_properties_hash["cpu_speed"] = (vm_host[:hz].to_f / 1000000).to_s if vm_host[:hz].present?

        system_hash = {}
        system_hash["architecture"] = (vm["guest.guestId"].index("64") ? "x64" : "x32") if vm["guest.guestId"].present?
        system_hash["operating_system"] = vm["guest.guestFullName"] if vm["guest.guestFullName"].present?
        vm_properties_hash["system"] = system_hash

        vm_properties_hash["disks"] = []
        vm_properties_hash["nics"] = []
        vm["config.hardware.device"].each do |vd|
          case vd
          when Vim::VirtualDisk
            vm_properties_hash["disks"] << get_disk(vd, vm)
          #when Vim::VirtualPCNet32, Vim::VirtualE1000, Vim::VirtualVmxnet
          when Vim::VirtualEthernetCard
            vm_properties_hash["nics"] << get_nic(vd, vm)
          end
        end

        virtual_machines_with_properties << vm_properties_hash
      end
    end

    return virtual_machines_with_properties
	end

  DISK_TYPES_WITH_UUID = [
    Vim::VirtualDiskFlatVer2BackingInfo,
    Vim::VirtualDiskRawDiskMappingVer1BackingInfo,
    Vim::VirtualDiskRawDiskVer2BackingInfo,
    Vim::VirtualDiskSparseVer2BackingInfo,
    Vim::VirtualDiskSeSparseBackingInfo,
  ]

  def get_disk(disk, properties)
    logger.info "vmware_api_adaptor.get_disk"
    disk_hash = {}
    disk_hash["type"] = "Disk"
    disk_hash["maximum_size"] = (disk.get_capacity_in_kb.to_i * KB) # if disk.get_capacity_in_kb
    disk_hash["controller_key"] = disk.get_controller_key # if disk.get_controller_key
    disk_hash["unit_number"] = disk.get_unit_number # if disk.get_unit_number
    disk_hash["name"] = disk.get_device_info.get_label # if disk.get_device_info && disk.get_device_info.get_label
    disk_hash["key"] = disk.get_key # if disk.get_key

    backing = disk.get_backing

    if DISK_TYPES_WITH_UUID.include?(backing.class)
      disk_hash["uuid"] = backing.get_uuid if backing.get_uuid
      disk_hash["disk_mode"] = backing.get_disk_mode if backing.get_disk_mode
    end

    case backing
    when Vim::VirtualDiskFlatVer2BackingInfo
      disk_hash["split"] = backing.get_split if backing.get_split
      disk_hash["write_through"] = backing.get_write_through if backing.get_write_through
      disk_hash["thin"] = backing.get_thin_provisioned if backing.get_thin_provisioned
      disk_hash["file_name"] = backing.get_file_name if backing.get_file_name
    when Vim::VirtualDiskRawDiskMappingVer1BackingInfo
      disk_hash["compatability_mode"] = backing.get_compatibility_mode if backing.get_compatibility_mode
      disk_hash["device_name"] = backing.get_device_name if backing.get_device_name
      disk_hash["lun_uuid"] = backing.get_lun_uuid if backing.get_lun_uuid
      disk_hash["uuid"] = backing.get_lun_uuid if backing.get_lun_uuid
      # disk_hash["uuid"] = backing.getUuid if backing.getUuid
    when Vim::VirtualDiskRawDiskVer2BackingInfo
      disk_hash["device_name"] = backing.get_device_name if backing.get_device_name
      disk_hash["descriptive_file_name"] = backing.get_descriptor_file_name if backing.get_descriptor_file_name
    when Vim::VirtualDiskSparseVer2BackingInfo
      disk_hash["split"] = backing.get_split if backing.get_split
      disk_hash["write_through"] = backing.get_write_through if backing.get_write_through
      disk_hash["space_used_in_kb"] = backing.getSpaceUsedInKB if backing.getSpaceUsedInKB
    when Vim::VirtualDiskSeSparseBackingInfo
      disk_hash["write_through"] = backing.get_write_through if backing.get_write_through
      disk_hash["delta_disk_format"] = backing.get_delta_disk_format if backing.get_delta_disk_format
      disk_hash["digest_enabled"] = backing.get_digest_enabled if backing.get_digest_enabled
      disk_hash["grain_size"] = backing.get_grain_size if backing.get_grain_size
    end
    return disk_hash
  end

  def get_nic(vNic, properties)
    logger.info "vmware_api_adaptor.get_nic";
    nic_hash = {}
    nic_hash["mac_address"] = vNic.get_mac_address if vNic.get_mac_address
    nic_hash["name"] = vNic.get_device_info.get_label if vNic.get_device_info.get_label
    nic_hash["key"] = vNic.get_key if vNic.get_key
    nic_hash["uuid"] = ("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa" + vNic.get_key.to_s) if vNic.get_key

    # There has to be a better way of getting a Nics IP address, because this is terrible
    if properties["guest.net"] && properties["guest.net"].respond_to?("each")
      properties["guest.net"].each do |gn|
        if gn.get_device_config_id == vNic.get_key
          if gn.instance_of?(Vim::GuestNicInfo) && !gn.get_ip_address.nil?
            nic_hash["ip_address"] = gn.get_ip_address.first
            nic_hash["network"] = gn.get_network
          end
        end
      end
    end
    return nic_hash
  end

	def find_vm_by_uuid(_uuid)
    logger.info("vmware_api_adaptor.find_vm_by_uuid");
    v = [self.connection.get_search_index.find_by_uuid(nil, _uuid, true, false)]
    vm = gather_properties(v);
    return vm
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