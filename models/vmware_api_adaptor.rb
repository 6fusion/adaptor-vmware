require 'java'
Dir['lib/java/**/*.jar'].each do |jar|
  $CLASSPATH << jar
  logger.info("#{jar}")
  require jar
end
$CLASSPATH << "#{PADRINO_ROOT}/lib/java"
java_import "java.net.URL"
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
  	disconnect
  	@connection = VIJava::ServiceInstance.new(URL.new("https://#{_host}/sdk"), _user, _password, true)
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

  def get_about_info
    logger.info("vmware_api_adaptor.get_about_info")
    about = self.connection.get_about_info
    about_hash = {}
    about_hash["fullName"] = about.get_full_name
    about_hash["vendor"] = about.get_vendor
    about_hash["version"] = about.get_version
    about_hash["build"] = about.get_build
    about_hash["localeVersion"] = about.get_locale_version
    about_hash["localeBuild"] = about.get_locale_build
    about_hash["osType"] = about.get_os_type
    about_hash["productLineId"] = about.get_product_line_id
    about_hash["apiType"] = about.get_api_type
    about_hash["apiVersion"] = about.get_api_version
    about_hash["instanceUuid"] = about.get_instance_uuid
    about_hash["licenseProductVersion"] = about.get_license_product_name
    about_hash["name"] = about.get_name

    dynamic_properties = about.get_dynamic_property
    unless dynamic_properties.nil?
      dynamic_properties.each do |dp|
        about_hash[dp.get_name.to_s] = dp.get_value.to_s
      end
    end

    return about_hash
  end

  def get_statistic_levels
    logger.info("vmware_api_adaptor.get_statistic_levels")
    performance_manager = self.connection.get_performance_manager
    performance_intervals = performance_manager.get_historical_interval
    stats = []

    unless performance_intervals.nil?
      performance_intervals.each do |pi|
        pi_hash = {}
        pi_hash["key"] = pi.get_key.to_s
        pi_hash["samplingPeriod"] = pi.get_sampling_period.to_s
        pi_hash["name"] = pi.get_name
        pi_hash["length"] = pi.get_length.to_s
        pi_hash["level"] = pi.get_level.to_s
        pi_hash["enabled"] = pi.is_enabled.to_s
        stats << pi_hash
      end
    end

    return stats
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
          :mor => h,
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
  # Datastores
  # --------------------------------------------------------

  def datastores(_get_disks=false)
    logger.info("vmware_api_adaptor.datastores")
    datastores = []
    self.hosts.each do |host|
      hdsb = host[:mor].get_datastore_browser
      hdsb.get_datastores.each do |ds|
        # don't build a hash, or add it to the list of datastores if it's already there
        if datastores.select {|d| d["moref_id"] == ds.get_mor.get_value }.empty?
          ds_hash = {}
          ds_hash["mor"] = ds
          ds_hash["moref_id"] = ds.get_mor.get_value
          ds_hash["name"] = ds.get_info.get_name
          ds_hash["type"] = ds.get_summary.get_type
          ds_hash["max_file_size"] = ds.get_info.get_max_file_size if ds.get_info.get_max_file_size
          ds_hash["free_space"] = ds.get_info.get_free_space if ds.get_info.get_free_space
          ds_hash["url"] = ds.get_info.get_url if ds.get_info.get_url
          ds_hash["media_files"] = virtual_disks(ds) if _get_disks
          # Get NFS/NAS info if it exists
          if ds.get_info.instance_of?(Vim::NasDatastoreInfo)
            ds_hash["remote_path"] = ds.get_info.nas.get_remote_path
            ds_hash["remote_host"] = ds.get_info.nas.get_remote_host
          end
          datastores << ds_hash
        end
      end
    end

    datastores
  end

  # this is really slow for a lot of disks, needs to be updated
  def virtual_disks(_datastore)
    logger.info("vmware_api_adaptor.virtual_disks")
    ds_browser = _datastore.get_browser
    v_disk_filter = Vim::VmDiskFileQueryFilter.new()
    v_disk_filter.set_controller_type(["VirtualIDEController"].to_java(:string))
    #file_query_flags = Vim::FileQueryFlags.new()
    #file_query_flags.set_file_type(true)
    #file_query_flags.set_file_size(true)
    #file_query_flags.set_modification(true)
    search_spec = Vim::HostDatastoreBrowserSearchSpec.new()
    #search_spec.set_details(file_query_flags)
    #search_spec.set_sort_folders_first(true)
    #search_spec.set_match_pattern(["*.vmdk"].to_java(:string)) #
    search_spec.set_query([Vim::VmDiskFileQuery.new()])

    media_files = []

    logger.info "task start"
    temp_task = ds_browser.searchDatastoreSubFolders_Task("[#{_datastore.get_info.get_name}]", search_spec)
    sleep(0.01) while ["queued", "running"].include?(temp_task.get_task_info.get_state.to_s)
    logger.info "task done"
    results = temp_task.get_task_info.get_result.get_host_datastore_browser_search_results
    results.each do |r|
      logger.info "\tinspecting result"
      if r.file.present?
        r.file.each do |f|
          logger.info "\t\tinspecting file"
          media_files << {
            "path" => f.get_path
          }
        end
      end
    end

    return media_files
  end

  # --------------------------------------------------------
  # Networks
  # --------------------------------------------------------

  def networks
    logger.info("vmware_api_adaptor.networks")
    networks = []
    self.hosts.each do |host|
      host[:mor].get_networks.each do |network|
        # don't build a hash, or add it to the list of networks if it's already there
        if networks.select {|d| d["moref_id"] == network.get_mor.get_value }.empty?
          network_hash = {}
          network_hash["mor"] = network
          network_hash["moref_id"] = network.get_mor.get_value
          network_hash["name"] = network.get_name if network.get_name
          network_hash["is_accessible"] = network.get_summary.is_accessible if network.get_summary.is_accessible
          network_hash["ip_pool_name"] = network.get_summary.get_ip_pool_name if network.get_summary.get_ip_pool_name
          networks << network_hash
        end
      end
    end

    networks
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
        vm_properties_hash["mor"] = vm_managed_object
        vm_properties_hash["external_vm_id"] = vm_mor_id if vm_mor_id.present?
        vm_properties_hash["external_host_id"] =  vm["runtime.host"].get_value if vm["runtime.host"].get_value.present?
        vm_properties_hash["uuid"] = vm["config.uuid"] if vm["config.uuid"].present?
        vm_properties_hash["name"] = vm["name"] if vm["name"].present?
        vm_properties_hash["cpu_count"] = vm["config.hardware.numCPU"] if vm["config.hardware.numCPU"].present?
        vm_properties_hash["maximum_memory"] = vm["config.hardware.memoryMB"] if vm["config.hardware.memoryMB"].present?
        vm_properties_hash["power_state"] = vm["runtime.powerState"].to_s if vm["runtime.powerState"].present?
        vm_properties_hash["cpu_speed"] = (vm_host[:hz].to_f / 1000000).to_s if vm_host[:hz].present?
        vm_properties_hash["guest_agent"] = (vm["guest.toolsStatus"] == "toolsNotInstalled" ? false : true)

        system_array = {}
        system_array["architecture"] = (vm["guest.guestId"].to_s.include?("64") ? "x64" : "x32")
        operating_system_hash = {}
        operating_system_hash["name"] = vm["guest.guestFullName"] if vm["guest.guestFullName"]
        operating_system_hash["distro"] = vm["guest.guestId"]
        system_array["operating_system"] = operating_system_hash
        vm_properties_hash["system"] = system_array

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
    disk_hash["thin"] = false

    backing = disk.get_backing

    if DISK_TYPES_WITH_UUID.include?(backing.class)
      disk_hash["uuid"] = backing.get_uuid if backing.get_uuid
      disk_hash["disk_mode"] = backing.get_disk_mode if backing.get_disk_mode
    end

    # grab backing specific metainfo
    case backing
    when Vim::VirtualDiskFlatVer2BackingInfo
      disk_hash["split"] = backing.get_split if backing.get_split
      disk_hash["write_through"] = backing.get_write_through if backing.get_write_through
      disk_hash["thin"] = (backing.get_thin_provisioned ? true : false)
      disk_hash["file_name"] = backing.get_file_name if backing.get_file_name
    when Vim::VirtualDiskRawDiskMappingVer1BackingInfo
      disk_hash["type"] = "Shared"
      disk_hash["compatability_mode"] = backing.get_compatibility_mode if backing.get_compatibility_mode
      disk_hash["device_name"] = backing.get_device_name if backing.get_device_name
      disk_hash["lun_uuid"] = backing.get_lun_uuid if backing.get_lun_uuid
      disk_hash["uuid"] = backing.get_lun_uuid if backing.get_lun_uuid
      # disk_hash["uuid"] = backing.getUuid if backing.getUuid
    when Vim::VirtualDiskRawDiskVer2BackingInfo
      disk_hash["type"] = "Shared"
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

    # get disk usage
    disk_hash["usage"] = 0.0
    if properties["layoutEx.disk"]
      layout_ex_disk = properties["layoutEx.disk"]
      layout_ex_disk.each do |led|
        if led.get_key == disk.get_key
          disk_units = led.get_chain
          if disk_units.present?
            disk_units.each do |unit|
              if properties["layoutEx.file"]
                properties["layoutEx.file"].each do |layout_ex|
                  unit.get_file_key.each do |file_key|
                    if layout_ex.get_key == file_key
                      disk_hash["usage"] += layout_ex.size * GB
                    end
                  end
                end
              end
            end
          end
        end
      end
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
    vm = gather_properties(v)
    return vm
  end

  def find_vm_by_mor(_mor)
    v = [VIJavaUtil::MorUtil.createExactManagedEntity(self.connection.get_server_connection, _mor)]
    vm = gather_properties(v)
    return vm
  end

  def start(_uuid)
    begin
  		logger.info("vmware_api_adaptor.start")
    	machine = find_vm_by_uuid(_uuid)
      tasks = []
      machine.map { |vm| tasks << vm["mor"].power_on_vm_task(nil) }
      tasks.each do |t|
        if t.present?
          sleep(1) while ["queued", "running"].include?(t.get_task_info.get_state.to_s)
          if t.get_task_info.get_state.to_s.include?("error")
            raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{t.get_task_info.get_error.get_localized_message.to_s}")
          end
        end
      end
    rescue Java::RuntimeFault,
      Java::RemoteException => e
      logger.warn("Invalid #{e.get_localized_message.to_s}")
      raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{e.class.to_s}")
    rescue Vim::InvalidState,
      Vim::TaskInProgress => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::MethodNotAllowed.new("Method Not Allowed: #{e.class.to_s}")
    end
  end

  def stop(_uuid)
    begin
      logger.info("vmware_api_adaptor.stop")
      machine = find_vm_by_uuid(_uuid)
      tasks = []
      machine.map { |vm| tasks << vm["mor"].shutdown_guest }
      tasks.each do |t|
        if t.present?
          sleep(1) while ["queued", "running"].include?(t.get_task_info.get_state.to_s)
          if t.get_task_info.get_state.to_s.include?("error")
            raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{t.get_task_info.get_error.get_localized_message.to_s}")
          end
        end
      end
    rescue Java::RuntimeFault,
      Java::RemoteException => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{e.class.to_s}")
    rescue Vim::InvalidState,
      Vim::TaskInProgress => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::MethodNotAllowed.new("Method Not Allowed: #{e.class.to_s}")
    end
  end

  def force_stop(_uuid)
    begin
    	logger.info("vmware_api_adaptor.stop")
      machine = find_vm_by_uuid(_uuid)
      tasks = []
      machine.map { |vm| tasks << vm["mor"].power_off_vm_task }
      tasks.each do |t|
        if t.present?
          sleep(1) while ["queued", "running"].include?(t.get_task_info.get_state.to_s)
          if t.get_task_info.get_state.to_s.include?("error")
            raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{t.get_task_info.get_error.get_localized_message.to_s}")
          end
        end
      end
    rescue Java::RuntimeFault,
      Java::RemoteException => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{e.class.to_s}")
    rescue Vim::InvalidState,
      Vim::TaskInProgress => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::MethodNotAllowed.new("Method Not Allowed: #{e.class.to_s}")
    end
  end

  def restart(_uuid)
  	begin
	  	logger.info("vmware_api_adaptor.restart")
	    machine = find_vm_by_uuid(_uuid)
      tasks = []
	    machine.map { |vm| tasks << vm["mor"].reboot_guest }
      tasks.each do |t|
        if t.present?
          sleep(1) while ["queued", "running"].include?(t.get_task_info.get_state.to_s)
          if t.get_task_info.get_state.to_s.include?("error")
            raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{t.get_task_info.get_error.get_localized_message.to_s}")
          end
        end
      end
    rescue Java::RuntimeFault,
      Java::RemoteException => e
    	logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{e.class.to_s}")
    rescue Vim::InvalidState,
      Vim::ToolsUnavailable,
      Vim::TaskInProgress => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::MethodNotAllowed.new("Method Not Allowed: #{e.class.to_s}")
    end
  end

  def force_restart(_uuid)
    begin
      logger.info("vmware_api_adaptor.restart")
      machine = find_vm_by_uuid(_uuid)
      tasks = []
      machine.map { |vm| tasks << vm["mor"].reset_vm_task }
      tasks.each do |t|
        if t.present?
          sleep(1) while ["queued", "running"].include?(t.get_task_info.get_state.to_s)
          if t.get_task_info.get_state.to_s.include?("error")
            raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{t.get_task_info.get_error.get_localized_message.to_s}")
          end
        end
      end
    rescue Java::RuntimeFault,
      Java::RemoteException => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{e.class.to_s}")
    rescue Vim::InvalidState,
      Vim::ToolsUnavailable,
      Vim::TaskInProgress => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::MethodNotAllowed.new("Method Not Allowed: #{e.class.to_s}")
    end
  end

  # --------------------------------------------------------
  # Readings
  # --------------------------------------------------------

  def readings(_vms, _start_time, _end_time)
    logger.info("vmware_api_adaptor.gather_counters")
    if _vms.present?
      performance_metrics = [
        { :metric_name => "cpu.usage.average", :instance => ""},
        { :metric_name => "cpu.usagemhz.average", :instance => ""},
        { :metric_name => "mem.consumed.average", :instance => ""},
        { :metric_name => "virtualDisk.read.average", :instance => "*"},
        { :metric_name => "virtualDisk.write.average", :instance => "*"},
        { :metric_name => "net.received.average", :instance => "*"},
        { :metric_name => "net.transmitted.average", :instance => "*"},
      ]

      # build performance metric hash with counter keys, and performance metric id array for query
      performance_manager = self.connection.get_performance_manager
      performance_counter_info = performance_manager.get_perf_counter
      perf_metric_ids = []
      performance_counter_info.each do |pci|
        perf_counter = "#{pci.get_group_info.get_key.to_s}.#{pci.get_name_info.get_key.to_s}.#{pci.get_rollup_type.to_s}"
        perf_metric = performance_metrics.select { |e| e[:metric_name].downcase == perf_counter.downcase }.first
        if perf_metric.present?
          perf_metric[:perf_metric_key] = pci.get_key.to_i
          temp_perf_metric_id = Vim::PerfMetricId.new()
          temp_perf_metric_id.set_counter_id(pci.get_key)
          temp_perf_metric_id.set_instance(perf_metric[:instance])
          perf_metric_ids << temp_perf_metric_id
        end
      end

      query_spec_list = []

      _vms.each do |vm|
        temp_perf_query_spec = Vim::PerfQuerySpec.new()
        temp_perf_query_spec.set_entity(vm["mor"].get_mor)
        temp_perf_query_spec.set_format("normal");
        temp_perf_query_spec.set_interval_id(300);
        temp_perf_query_spec.set_metric_id(perf_metric_ids)
        temp_perf_query_spec.set_start_time(_start_time.utc)
        temp_perf_query_spec.set_end_time(_end_time.utc)
        query_spec_list << temp_perf_query_spec

        # add empty readings here to avoid having to interate over the array again
        vm["stats"] = {}
        ((_start_time.utc + 5.minutes).._end_time.utc).step(5.minutes) do |ts|
          vm["stats"][ts.strftime("%Y-%m-%dT%H:%M:%SZ")] = {
            "virtualDisk.read.average.*" => 0,
            "virtualDisk.write.average.*" => 0,
            "net.received.average.*" => 0,
            "net.transmitted.average.*" => 0
          }
        end
      end


      logger.info "start performance_manager.query_perf"
      performance_entity_metric_base = performance_manager.query_perf(query_spec_list)
      # parse timestamps?
      logger.info "end performance_manager.query_perf"

      unless performance_entity_metric_base.nil?
        performance_entity_metric_base.each do |pemb|
          if pemb.instance_of?(Vim::PerfEntityMetric)
            infos = pemb.get_sample_info
            values = pemb.get_value

            entity = _vms.select { |e| e["external_vm_id"] == pemb.get_entity.get_value }.first
            if infos.present?
              infos.each_with_index do |info, info_index|
                metric_hash = {}
                timestamp = info.get_timestamp.get_time.to_s.to_datetime.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
                metric_hash["timestamp"] = timestamp
                if values.present?
                  values.each do |value|
                    metric = performance_metrics.select { |e| e[:perf_metric_key] == value.get_id.get_counter_id }.first
                    metric_name = ( value.get_id.get_instance.to_s.length > 0 ? "#{metric[:metric_name]}.#{value.get_id.get_instance}" : "#{metric[:metric_name]}" )
                    if value.instance_of?(Vim::PerfMetricIntSeries)
                      long_values = value.get_value
                      metric_hash[metric_name] = long_values[info_index]
                    end
                  end
                end

                entity["stats"][timestamp] = metric_hash
              end
            end
          end
        end
      end

      return _vms
    end
    return nil
  end

end