require 'java'
require 'benchmark'
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
    about                               = self.connection.get_about_info
    about_hash                          = {}
    about_hash["fullName"]              = about.get_full_name
    about_hash["vendor"]                = about.get_vendor
    about_hash["version"]               = about.get_version
    about_hash["build"]                 = about.get_build
    about_hash["localeVersion"]         = about.get_locale_version
    about_hash["localeBuild"]           = about.get_locale_build
    about_hash["osType"]                = about.get_os_type
    about_hash["productLineId"]         = about.get_product_line_id
    about_hash["apiType"]               = about.get_api_type
    about_hash["apiVersion"]            = about.get_api_version
    about_hash["instanceUuid"]          = about.get_instance_uuid
    about_hash["licenseProductVersion"] = about.get_license_product_name
    about_hash["name"]                  = about.get_name

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
    performance_manager   = self.connection.get_performance_manager
    performance_intervals = performance_manager.get_historical_interval
    stats                 = []

    unless performance_intervals.nil?
      performance_intervals.each do |pi|
        pi_hash                   = {}
        pi_hash["key"]            = pi.get_key.to_s
        pi_hash["samplingPeriod"] = pi.get_sampling_period.to_s
        pi_hash["name"]           = pi.get_name
        pi_hash["length"]         = pi.get_length.to_s
        pi_hash["level"]          = pi.get_level.to_s
        pi_hash["enabled"]        = pi.is_enabled.to_s
        stats << pi_hash
      end
    end

    return stats
  end

  def get_session_info
    session_manager = self.connection.get_session_manager
    user_sessions = session_manager.get_session_list
    session_info = {
      count: user_sessions.count
    }
    session_info[:sessions] = user_sessions.map { |us|
      {
        session_key: us.get_key,
        user_name: us.get_user_name,
        locale: us.get_locale,
        login_time: us.get_login_time.get_time.to_s.to_datetime.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
        last_active_time: us.get_last_active_time.get_time.to_s.to_datetime.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      }
    }
    session_info
  end

  # --------------------------------------------------------
  # Hosts
  # --------------------------------------------------------

  HOST_PROPERTIES = %w(
    name
    hardware.cpuInfo.hz
    hardware.memorySize
  )

  def hosts()
    logger.info("vmware_api_adaptor.hosts");
    host_managed_objects = VIJava::InventoryNavigator.new(self.root_folder).search_managed_entities("HostSystem");
    host_properties = VIJavaUtil::PropertyCollectorUtil.retrieve_properties(host_managed_objects, "HostSystem", HOST_PROPERTIES.to_java(:string))

    host_properties_hash = {}
    host_properties.each { |host| host_properties_hash[host["name"]] = host }

    _hosts = []
    host_managed_objects.each do |h|
      prop_record = host_properties_hash.delete(h.name)
      if prop_record.present?
        _hosts << {
            :mor        => h,
            :host_id    => h.get_mor.get_value,
            :name       => prop_record["name"],
            :hz         => prop_record["hardware.cpuInfo.hz"],
            :memorySize => prop_record["hardware.memorySize"],
        }
      end
    end

    return _hosts
  end

  # --------------------------------------------------------
  # Datastores
  # --------------------------------------------------------

  def get_datastores_by_host(_host_mor, _get_disks=false)
    host_datastores = []

    _host_mor.get_datastores.each do |ds|
      ds.refresh_datastore

      # don't build a hash, or add it to the list of datastores if it's already there
      if host_datastores.select { |d| d["moref_id"] == ds.get_mor.get_value }.empty?
        ds_hash             = {}
        ds_hash["host_mor"] = _host_mor
        ds_hash["mor"]      = ds
        ds_hash["moref_id"] = ds.get_mor.get_value
        ds_hash["name"]     = ds.get_info.get_name
        ds_hash["type"]     = ds.get_summary.get_type
        ds_hash["max_file_size"] = ds.get_info.get_max_file_size if ds.get_info.get_max_file_size
        ds_hash["free_space"] = ds.get_info.get_free_space if ds.get_info.get_free_space
        ds_hash["url"] = ds.get_info.get_url if ds.get_info.get_url
        ds_hash["media_files"] = virtual_disks(ds) if _get_disks
        # Get NFS/NAS info if it exists
        if ds.get_info.instance_of?(Vim::NasDatastoreInfo)
          ds_hash["remote_path"] = ds.get_info.nas.get_remote_path
          ds_hash["remote_host"] = ds.get_info.nas.get_remote_host
        end

        host_datastores << ds_hash
      end
    end

    return host_datastores
  end

  def datastores(_get_disks=false)
    logger.info("vmware_api_adaptor.datastores")
    datastores = []
    self.hosts.each do |host|
      datastores << get_datastores_by_host(host[:mor], _get_disks)
    end

    datastores.flatten
  end

  # this is really slow for a lot of disks, needs to be updated
  def virtual_disks(_datastore)
    logger.info("vmware_api_adaptor.virtual_disks")
    ds_browser    = _datastore.get_browser
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
  # Tasks
  # --------------------------------------------------------

  def tasks
    all_tasks    = []
    task_manager = self.connection.get_task_manager
    task_manager.get_recent_tasks.each do |task|
      task_info = task.get_task_info
      all_tasks << {
          :state          => task_info.get_state.to_s,
          :description_id => task_info.get_description_id,
          :description    => task_info.get_description,
          :entity_mor     => task_info.get_entity,
          :entity_name    => task_info.get_entity_name
      }
    end

    all_tasks
  end

  # --------------------------------------------------------
  # Networks
  # --------------------------------------------------------

  # TODO: is_accessible and ip_pool_name may not be required
  def networks
    logger.info("vmware_api_adaptor.networks")
    network_mors = self.hosts.map { |host| host[:mor].get_networks }.flatten.uniq { |network| network.get_mor.get_value }
    network_mors.map do |network|
      {
          "mor" =>           network,
          "moref_id" =>      network.get_mor.get_value,
          "name" =>          network.get_name,
          "is_accessible" => network.get_summary.is_accessible,
          "ip_pool_name" =>  network.get_summary.get_ip_pool_name
      }
    end
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

  BLOCKING_TASKS = %w(
    ResourcePool.ImportVAppLRO
  )

  def gather_properties(vms, _include_deploying=false)
    logger.info("vmware_api_adaptor.gather_properties")
    _hosts = self.hosts
    vms_with_properties = VIJavaUtil::PropertyCollectorUtil.retrieve_properties(vms, "VirtualMachine", VM_PROPERTIES.to_java(:string))

    vms_hash = {}
    vms.each { |vm| vms_hash[vm.config.uuid] = vm if vm.config.present? }

    virtual_machines_with_properties = []
    vms_with_properties.each do |vm|
      exclude_deploying = !_include_deploying && tasks.find { |t| BLOCKING_TASKS.include?(t[:description_id]) && t[:entity_name] == vm["name"] && ["running", "queued"].include?(t[:state]) }.present?
      unless vm["config.template"] || exclude_deploying
        vm_managed_object  = vms_hash.delete(vm["config.uuid"])
        next if vm_managed_object.nil?
        vm_host            = _hosts.find { |e| e[:host_id] == vm["runtime.host"].get_value }
        vm_properties_hash = {}

        vm_mor_id                 = vm_managed_object.get_mor.get_value.to_s
        account_id_match          = vm_managed_object.get_parent.get_name.match(/Account(\d*)/)
        vm_properties_hash["mor"] = vm_managed_object
        vm_properties_hash["external_vm_id"] = vm_mor_id if vm_mor_id.present?
        vm_properties_hash["external_host_id"] = vm["runtime.host"].get_value if vm["runtime.host"].get_value.present?
        vm_properties_hash["uuid"] = vm["config.uuid"] if vm["config.uuid"].present?
        vm_properties_hash["name"] = vm["name"] if vm["name"].present?
        vm_properties_hash["cpu_count"] = vm["config.hardware.numCPU"] if vm["config.hardware.numCPU"].present?
        vm_properties_hash["maximum_memory"] = (vm["config.hardware.memoryMB"].to_f * MB) if vm["config.hardware.memoryMB"].present?
        vm_properties_hash["power_state"] = convert_power_state(vm["guest.toolsStatus"].to_s, vm["runtime.powerState"].to_s) if vm["runtime.powerState"].present?
        vm_properties_hash["cpu_speed"] = (vm_host[:hz].to_f / 1000000).to_s if vm_host[:hz].present?
        vm_properties_hash["guest_agent"] = (vm["guest.toolsStatus"].to_s == "toolsOk" || vm["guest.toolsStatus"].to_s == "toolsOld" ? true : false)
        vm_properties_hash["account_id"]  = account_id_match.present? ? account_id_match[1] : ""

        system_array                 = {}
        system_array["architecture"] = (vm["guest.guestId"].to_s.include?("64") ? "x64" : "x32")
        operating_system_hash        = {}
        operating_system_hash["name"] = vm["guest.guestFullName"] if vm["guest.guestFullName"]
        operating_system_hash["distro"]  = vm["guest.guestId"]
        system_array["operating_system"] = operating_system_hash
        vm_properties_hash["system"]     = system_array

        vm_properties_hash["disks"] = []
        vm_properties_hash["nics"]  = []
        vm["config.hardware.device"].each do |vd|
          case vd
            when Vim::VirtualDisk
              vm_properties_hash["disks"] << get_disk(vd, vm)
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
    disk_hash                   = {}
    disk_hash["type"]           = "Disk"
    disk_hash["maximum_size"]   = (disk.get_capacity_in_kb.to_i * KB) # if disk.get_capacity_in_kb
    disk_hash["controller_key"] = disk.get_controller_key             # if disk.get_controller_key
    disk_hash["unit_number"]    = disk.get_unit_number                # if disk.get_unit_number
    disk_hash["name"]           = disk.get_device_info.get_label      # if disk.get_device_info && disk.get_device_info.get_label
    disk_hash["key"]            = disk.get_key                        # if disk.get_key
    disk_hash["thin"]           = false

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
    _network_name = ""
    _backing = vNic.get_backing
    if _backing.respond_to?("get_port")
      _network_name = _backing.get_port.get_portgroup_key if _backing.get_port
    elsif _backing.respond_to?("get_network")
      _network_name = _backing.get_network.get_value if _backing.get_network
    end

    nic_hash["network_uuid"] = _network_name

    if properties["guest.net"] && properties["guest.net"].respond_to?("each")
      properties["guest.net"].each do |gn|
        if gn.get_device_config_id == vNic.get_key
          if gn.instance_of?(Vim::GuestNicInfo)
            nic_hash["ip_address"] = gn.get_ip_address.first if !gn.get_ip_address.nil?
          end
        end
      end
    end

    return nic_hash
  end

  def find_vm_by_uuid(_uuid, _include_deploying=false)
    logger.info("vmware_api_adaptor.find_vm_by_uuid")
    v  = [self.connection.get_search_index.find_by_uuid(nil, _uuid, true, false)]
    raise Exceptions::NotFound, "Unable to find machine by uuid: #{_uuid}" unless v.present?
    vm = gather_properties(v, _include_deploying)
    raise Exceptions::NotFound, "Unable to find machine by uuid: #{_uuid}" unless vm.present?

    return vm.first
  end

  def find_vm_by_mor(_mor, _include_deploying=false)
    logger.info("vmware_api_adaptor.find_vm_by_mor")
    v  = [VIJavaUtil::MorUtil.createExactManagedEntity(self.connection.get_server_connection, _mor)]
    vm = gather_properties(v, _include_deploying)

    return vm.first
  end

  # runtime.powerState, guest.guestState, guest.net
  def get_vm_property(_mor, _property_name)
    logger.info("vmware_api_adaptor.get_vm_property(#{_property_name}) for #{_mor}")
    VIJavaUtil::PropertyCollectorUtil.retrieve_properties([_mor], "VirtualMachine", [_property_name].to_java(:string)).each do |vm|
      return vm[_property_name]
    end
  end

  def wait_for_full_boot(_machine)
    # die if no guest tools installed on the virtual machine
    return if !_machine["guest_agent"]

    # logger.info("waiting for correct guest state")
    # sleep(1) while get_vm_property(_machine["mor"], "guest.guestState") != "running"

    logger.info("waiting for network cards to be initialized")
    timeout = 0
    # currently, unless you want to check for specific class assignments, the best way to check for nic_info is to see if it's an array
    while !get_vm_property(_machine["mor"], "guest.net").respond_to?("each") && timeout < 120
      timeout += 1
      sleep(1)
    end
  end

  def start(_uuid)
    begin
      logger.info("vmware_api_adaptor.start")
      machine = find_vm_by_uuid(_uuid)

      task = machine["mor"].power_on_vm_task(nil)
      if task.present?
        sleep(1) while ["queued", "running"].include?(task.get_task_info.get_state.to_s)
        if task.get_task_info.get_state.to_s.include?("error")
          raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{task.get_task_info.get_error.get_localized_message.to_s}")
        end
      end

      wait_for_full_boot(machine)
      machine = find_vm_by_uuid(_uuid)
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
      tasks   = []
      task    = machine["mor"].shutdown_guest

      if task.present?
        sleep(1) while ["queued", "running"].include?(task.get_task_info.get_state.to_s)
        if task.get_task_info.get_state.to_s.include?("error")
          raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{task.get_task_info.get_error.get_localized_message.to_s}")
        end
      end

      logger.info("waiting for correct power state")
      sleep(1) while !["poweredOff", "suspended"].include?(get_vm_property(machine["mor"], "runtime.powerState").to_s)
      find_vm_by_uuid(_uuid)
    rescue Java::RuntimeFault,
        Java::RemoteException => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{e.class.to_s}")
    rescue Vim::InvalidState,
        Vim::TaskInProgress => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::MethodNotAllowed.new("Method Not Allowed: #{e.class.to_s}")
    rescue Java::ComVmwareVim25::ToolsUnavailable => e
      logger.error("VMware Tools Unavailable")
      raise Exceptions::MethodNotAllowed.new("Method Not Allowed: VMware Tools Unavailable")
    end
  end

  def force_stop(_uuid)
    begin
      logger.info("vmware_api_adaptor.stop")
      machine = find_vm_by_uuid(_uuid)
      tasks   = []

      task = machine["mor"].power_off_vm_task

      if task.present?
        sleep(1) while ["queued", "running"].include?(task.get_task_info.get_state.to_s)
        if task.get_task_info.get_state.to_s.include?("error")
          raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{task.get_task_info.get_error.get_localized_message.to_s}")
        end
      end

      logger.info("waiting for correct power state")
      sleep(1) while !["poweredOff", "suspended"].include?(get_vm_property(machine["mor"], "runtime.powerState").to_s)
      find_vm_by_uuid(_uuid)
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
      tasks   = []

      task = machine["mor"].reboot_guest

      if task.present?
        sleep(1) while ["queued", "running"].include?(task.get_task_info.get_state.to_s)
        if task.get_task_info.get_state.to_s.include?("error")
          raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{task.get_task_info.get_error.get_localized_message.to_s}")
        end
      end

      wait_for_full_boot(machine)
      find_vm_by_uuid(_uuid)
    rescue Java::RuntimeFault,
        Java::RemoteException => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{e.class.to_s}")
    rescue Vim::InvalidState,
        Vim::TaskInProgress => e
      logger.warn("Invalid #{e.class.to_s}")
      raise Exceptions::MethodNotAllowed.new("Method Not Allowed: #{e.class.to_s}")
    rescue Java::ComVmwareVim25::ToolsUnavailable => e
      logger.error("VMware Tools Unavailable")
      raise Exceptions::MethodNotAllowed.new("Method Not Allowed: VMware Tools Unavailable")
    end
  end

  def force_restart(_uuid)
    begin
      logger.info("vmware_api_adaptor.restart")
      machine = find_vm_by_uuid(_uuid)
      tasks   = []

      task = machine["mor"].reset_vm_task

      if task.present?
        sleep(1) while ["queued", "running"].include?(task.get_task_info.get_state.to_s)
        if task.get_task_info.get_state.to_s.include?("error")
          raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{task.get_task_info.get_error.get_localized_message.to_s}")
        end
      end

      logger.info("waiting for correct power state")
      sleep(1) while get_vm_property(machine["mor"], "runtime.powerState").to_s != "poweredOn"
      find_vm_by_uuid(_uuid)
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

  def destroy(_uuid)
    begin
      logger.info("vmware_api_adaptor.destroy")
      machine = find_vm_by_uuid(_uuid)
      tasks   = []

      task = machine["mor"].destroy_task

      if task.present?
        sleep(1) while ["queued", "running"].include?(task.get_task_info.get_state.to_s)
        if task.get_task_info.get_state.to_s.include?("error")
          raise Exceptions::Unrecoverable.new("Cannot Complete Requested Action: #{task.get_task_info.get_error.get_localized_message.to_s}")
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

  # --------------------------------------------------------
  # Readings
  # --------------------------------------------------------

  def readings(_vms, _start_time, _end_time)
    logger.info("vmware_api_adaptor.gather_counters")
    if _vms.present?
      performance_metrics      = [
          { :metric_name => "cpu.usage.average", :instance => "" },
          { :metric_name => "cpu.usagemhz.average", :instance => "" },
          { :metric_name => "mem.consumed.average", :instance => "" },
          { :metric_name => "virtualDisk.read.average", :instance => "*" },
          { :metric_name => "virtualDisk.write.average", :instance => "*" },
          { :metric_name => "net.received.average", :instance => "*" },
          { :metric_name => "net.transmitted.average", :instance => "*" },
      ]

      # build performance metric hash with counter keys, and performance metric id array for query
      performance_manager      = self.connection.get_performance_manager
      performance_counter_info = performance_manager.get_perf_counter

      perf_metric_ids          = []
      performance_counter_info.each do |pci|
        perf_counter = "#{pci.get_group_info.get_key.to_s}.#{pci.get_name_info.get_key.to_s}.#{pci.get_rollup_type.to_s}"
        perf_metric  = performance_metrics.find { |e| e[:metric_name].downcase == perf_counter.downcase }
        if perf_metric.present?
          perf_metric[:perf_metric_key] = pci.get_key.to_i
          temp_perf_metric_id           = Vim::PerfMetricId.new()
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
              "virtualDisk.read.average.*"  => 0,
              "virtualDisk.write.average.*" => 0,
              "net.received.average.*"      => 0,
              "net.transmitted.average.*"   => 0
          }
        end
      end

      logger.info "start performance_manager.query_perf"
      performance_entity_metric_base = performance_manager.query_perf(query_spec_list)
      # parse timestamps?
      logger.info "end performance_manager.query_perf"

      unless performance_entity_metric_base.nil?
        vms_hash = {}
        _vms.each { |vm| vms_hash["external_vm_id"] = vm }
        performance_entity_metric_base.each do |pemb|
          if pemb.instance_of?(Vim::PerfEntityMetric)
            infos  = pemb.get_sample_info
            values = pemb.get_value

            entity = vms_hash.delete(pemb.get_entity.get_value)
            next if entity.nil?
            if infos.present?
              infos.each_with_index do |info, info_index|
                metric_hash              = {}
                timestamp                = info.get_timestamp.get_time.to_s.to_datetime.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
                metric_hash["timestamp"] = timestamp
                if values.present?
                  values.each do |value|
                    metric      = performance_metrics.find { |e| e[:perf_metric_key] == value.get_id.get_counter_id }
                    metric_name = (value.get_id.get_instance.to_s.length > 0 ? "#{metric[:metric_name]}.#{value.get_id.get_instance}" : "#{metric[:metric_name]}")
                    if value.instance_of?(Vim::PerfMetricIntSeries)
                      long_values              = value.get_value
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

  # Helper Method for converting machine power states.
  def convert_power_state(tools_status, power_status)
    logger.info('machine.convert_power_state')

    begin
      status = "#{tools_status}|#{power_status}"

      case status
      when "toolsOk|poweredOn"
        "started"
      when "toolsOld|poweredOn"
        "started"
      when "toolsNotInstalled|poweredOn"
        "started"
      when "toolsNotRunning|poweredOff"
        "stopped"
      when "toolsOld|poweredOff"
        "stopped"
      when "toolsNotInstalled|poweredOff"
        "stopped"
      when "toolsNotRunning|poweredOn"
        "started"
      else
        "Unknown"
      end
    rescue => e
      logger.error(e.message)
      raise Exceptions::Unrecoverable, e.message
    end
  end
end