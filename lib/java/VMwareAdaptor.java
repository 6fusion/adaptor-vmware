/**
 * @author      Geoff Corey <gcorey@6fusion.com>
 * @since       2012-12-09        
 */
import java.lang.reflect.Type;
import java.lang.Math;
import java.net.MalformedURLException;
import java.net.URL;
import java.rmi.RemoteException;
import java.util.*;
import java.util.logging.Level;
import java.util.logging.Logger;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import org.joda.time.format.ISODateTimeFormat;
import org.joda.time.format.DateTimeFormatter;
import org.joda.time.DateTimeZone;
import com.vmware.vim25.*;
import com.vmware.vim25.mo.*;
import com.vmware.vim25.mo.util.*;

public class VMwareAdaptor 
{
  private final static Logger logger = Logger.getLogger("VMwareAdaptor");
  private ServiceInstance si = null;
  private Folder rootFolder = null;
  // Hash of host-morefID to host hash of attributes / values
  public HashMap<String, HashMap<String, Object>> hostMap = new HashMap<String, HashMap<String, Object>>();
  // Hash of vm-UUID to vm hash of attributes / values
  public HashMap<String, HashMap<String, Object>> vmMap = new HashMap<String, HashMap<String, Object>>();
  // Hash of PerfCounter name to Counter ID
  public HashMap<String, Integer> counterMap = new HashMap<String, Integer>();
  // Hash of PerfCounter name to Counter ID to name
  public HashMap<Integer, String> counterIdMap = new HashMap<Integer, String>();
  // Set of Metric Timestamps
  public TreeSet<String> tsSet = new TreeSet<String>();
  // List of VirtualMachine MORs 
  // Utility Constants
  public final static long KB = 1024;
  public final static double MB = Math.pow(1024,2);
  public final static double GB = Math.pow(1024,3);
  public final static double TB = Math.pow(1024,4);
  // used for registering VMware Plugin
  public final static String EXT_KEY = "com.6fusion.cloudresourcemeter";
  public final static String EXT_COMPANY = "6fusion USA";
  public final static String EXT_TYPE = "com.vmware.vim.viClientScripts";
  public final static String EXT_VERSION = "3.1";
  public final static String EXT_LABEL = "6fusionCloudResourceMeter";
  public final static String[] EXT_ADMIN_EMAIL = {"support@6fusion.com"};

 /**
 * VMwareAdaptor - API adaptor between VI Java VMWARE API and JRUBY
 *
 * This class is a helper class to gather virtual machine info and
 * metric readings from VMware 4.1/5.0/5.1 vSphere
 * <p>
 * This class can be run standalone but the primary use is to provide
 * a bridge between JRUBY and the VI java VMWARE API to minimize the
 * passing of Java classes being utilized in Ruby.
 *
 * @param  url String vCenter API URL (Ex. https://192.168.100.110/sdk)
 * @param  username String vCenter username
 * @param  password String vCenter password
 */
  public VMwareAdaptor(String url, String username, String password ) throws Exception
  {
    ServiceInstance si = new ServiceInstance(new URL(url), username, password, true);
    this.si = si;
  }

  public void close()
  {
    this.si.getServerConnection().logout();
  }

  public Calendar currentTime() throws Exception
  {
    return this.si.currentTime();
  }

  private ExtensionManager getExtensionManager()
  {
    return si.getExtensionManager();
  }

  private PerformanceManager getPerformanceManager()
  {
    return si.getPerformanceManager();
  }

  public void register(String url) throws Exception
  {
    Extension extension = new Extension();
    Description description = new Description();
    ExtensionServerInfo serverInfo = new ExtensionServerInfo();
    DateTimeFormatter parser2 = ISODateTimeFormat.dateTimeNoMillis();
    Calendar lastHeartbeatTime = (Calendar) Calendar.getInstance(TimeZone.getTimeZone("GMT")).clone();
    lastHeartbeatTime.setTime(parser2.parseDateTime("2012-12-21T00:00:00Z").toDate());
    extension.setKey(VMwareAdaptor.EXT_KEY);
    extension.setCompany(VMwareAdaptor.EXT_COMPANY);
    extension.setType(VMwareAdaptor.EXT_TYPE);
    extension.setVersion(VMwareAdaptor.EXT_VERSION);
    extension.setLastHeartbeatTime(lastHeartbeatTime);
    description.setLabel(VMwareAdaptor.EXT_LABEL);
    description.setSummary(VMwareAdaptor.EXT_LABEL);
    extension.setDescription(description);
    serverInfo.setUrl(url);
    serverInfo.setDescription(description);
    serverInfo.setCompany(VMwareAdaptor.EXT_COMPANY);
    serverInfo.setType(VMwareAdaptor.EXT_TYPE);
    serverInfo.setAdminEmail(VMwareAdaptor.EXT_ADMIN_EMAIL);
    this.getExtensionManager().unregisterExtension(VMwareAdaptor.EXT_KEY);
    this.getExtensionManager().registerExtension(extension);
  }

  public HashMap<String, String>  getAboutInfo() throws Exception
  {
    logger.fine("Entering VMwareAdaptor.getAboutInfo()");
    AboutInfo about = this.si.getAboutInfo();
    HashMap<String, String> props = new HashMap<String, String>();
    props.put("name",about.getName());
    props.put("fullName",about.getFullName());
    props.put("vendor",about.getVendor());
    props.put("version",about.getVersion());
    props.put("build",about.getBuild());
    props.put("localeVersion",about.getLocaleVersion());
    props.put("localeBuild",about.getLocaleBuild());
    props.put("osType",about.getOsType());
    props.put("productLineId",about.getProductLineId());
    props.put("apiType",about.getApiType());
    props.put("apiVersion",about.getApiVersion());
    props.put("instanceUuid",about.getInstanceUuid());
    props.put("licenseProductVersion",about.getLicenseProductName());
    props.put("name",about.getName());

    for(int i=0; about.getDynamicProperty() !=null && i<about.getDynamicProperty().length; i++) {
      DynamicProperty dynamicProperty = about.getDynamicProperty()[i];
      props.put(dynamicProperty.getName(),dynamicProperty.getVal().toString());
    }
    logger.fine("Exiting VMwareAdaptor.getAboutInfo()");
    return props;
  }

  public List<HashMap<String, String>>  getStatisticLevels() throws Exception
  {
    logger.fine("Entering VMwareAdaptor.getStatisticLevels()");
    PerformanceManager perfMgr = this.si.getPerformanceManager();
    PerfInterval[] perfIntervals = perfMgr.getHistoricalInterval();
    ArrayList<HashMap<String, String>> stats = new ArrayList<HashMap<String, String>>();
    for(int i=0; perfIntervals !=null && i<perfIntervals.length; i++) {
      PerfInterval interval = perfIntervals[i];
      HashMap<String, String> props = new HashMap<String, String>();
      props.put("key",Integer.toString(interval.getKey()));
      props.put("samplingPeriod",Integer.toString(interval.getSamplingPeriod()));
      props.put("name",interval.getName());
      props.put("length",Integer.toString(interval.getLength()));
      props.put("level",interval.getLevel().toString());
      props.put("enabled",Boolean.toString(interval.isEnabled()));
      stats.add(props);
    }
    logger.fine("Exiting VMwareAdaptor.getStatisticLevels()");
    return stats;
  }

 /**
   * findByUuid 
   *
   * Fine the virtual machine by UUID 
   * <p>
   *
   * @param  uuid UUID of the virtural machine
   * @return virtual machine HashMap of properties 
   */
  public HashMap<String, Object> findByUuid(String uuid) throws Exception
  {
    logger.fine("Entering VMwareAdaptor.findByUuid(String uuid)");
    VirtualMachine[] vms = new VirtualMachine[1];
    VirtualMachine vm = (VirtualMachine) this.si.getSearchIndex().findByUuid(null,uuid,true,false);
    if (vm == null) {
      logger.info("Machine UUID "+uuid+" not found");
      return null;
    }
    vms[0] = vm;
    gatherProperties(vms);
    logger.fine("Exiting VMwareAdaptor.findByUuid(String uuid)");
    return vmMap.get(vm.getMOR().get_value().toString());
  }

  /**
   * findByUuidWithReadings 
   *
   * Find the virtual machine by UUID and assocated readings for a date range
   * <p>
   *
   * @param  uuid UUID of the virtural machine
   * @param  startIso8601 String representation of an ISO8601 date 
   * @param  endIso8601 String representation of an ISO8601 date 
   * @return virtual machine HashMap of properties and reading 
   */
  public HashMap<String, Object>  findByUuidWithReadings(String uuid, String startIso8601, String endIso8601) throws Exception
  {
    logger.fine("Entering VMwareAdaptor.findByUuidWithReadings()");
    VirtualMachine[] vms = new VirtualMachine[1];
    VirtualMachine vm = (VirtualMachine) this.si.getSearchIndex().findByUuid(null,uuid,true,false);
    DateTimeFormatter parser2 = ISODateTimeFormat.dateTimeNoMillis();
    Calendar startTime = (Calendar) Calendar.getInstance(TimeZone.getTimeZone("GMT")).clone();
    Calendar endTime = (Calendar) Calendar.getInstance(TimeZone.getTimeZone("GMT")).clone();
    startTime.setTime(parser2.parseDateTime(startIso8601).toDate());
    endTime.setTime(parser2.parseDateTime(endIso8601).toDate());
    if (vm == null) {
      logger.info("Machine UUID "+uuid+" not found");
      return null;
    }
    vms[0] = vm;
    gatherProperties(vms);
    List<VirtualMachine> vms_list = new ArrayList<VirtualMachine>(Arrays.asList(vms));
    readings(vms_list,startTime,endTime);
    logger.fine("Exiting VMwareAdaptor.findByUuidWithReadings()");
    return vmMap.get(vm.getMOR().get_value().toString());
  }


  /**
   * gatherVirtualMachines
   *
   * Populates this.hostMap and this.vmMap.
   * <p>
   * JSON representation of vmMap.
   *
   * {
   *   "vm-109": {
   *       "nics": [
   *           {
   *               "ip_address": "Unknown",
   *               "mac_address": "00:50:56:83:64:d5",
   *               "uuid": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa4000",
   *               "name": "Network adapter 1"
   *           }
   *       ],
   *       "system": {
   *           "operating_system": "debian4Guest",
   *           "architecture": "x32"
   *       },
   *       "maximum_memory": 256,
   *       "disks": [
   *           {
   *               "uuid": "6000C29e-d736-6461-d86c-df1603e11a67",
   *               "type": "Disk",
   *               "maximum_size": 0,
   *               "name": "Hard disk 1",
   *               "thin": false
   *           }
   *       ],
   *       "cpu_count": 1,
   *       "uuid": "42038ec5-83ff-867c-aa71-b1a1e59da225",
   *       "power_state": "started",
   *       "guest_agent": false,
   *       "name": "base-dsl-1012",
   *       "cpu_speed": 2666,
   *       "external_vm_id": "vm-88",
   *       "external_host_id": "host-48",
   *    }
   * }
   * vmMap Key:    VirtualMachien MORef
   * vmMap Values: uuid, name, cpu_count, cpu_speed, maximum_memory, guest_agent architecture,
   *               operating_system, power_state, disks and nics
   *
   *
   * Helper function for finding the hz for a Host MORef
   *
   * @return List<VirtualMachine> List of VirtualMachine objects from API call that can be used 
   *                              with this.readings as a parameter
   */
  public List<VirtualMachine>  gatherVirtualMachines() throws Exception
  {
    logger.fine("Entering VMwareAdaptor.gatherVirtualMachines()");
    Folder rootFolder = this.si.getRootFolder();
    ManagedEntity[] vms = new InventoryNavigator(rootFolder).searchManagedEntities("VirtualMachine");
    logger.fine("Exiting VMwareAdaptor.gatherVirtualMachines()");
    return(gatherProperties(vms));
  }

  /* gatherProperties
   *
   * @param  vms ManagedEntity[] array of ManagedEntities.
   * @return List<VirtualMachine> List of VirtualMachine objects from API call that can be used 
   *                              with this.readings as a parameter
   */
  private List<VirtualMachine> gatherProperties(ManagedEntity[] vms) throws Exception
  {
    logger.fine("Entering VMwareAdaptor.gatherProperties(ManagedEntity[] vms)");
    // vmsList is the result being returned
    List<VirtualMachine> vmsList = new ArrayList<VirtualMachine>(); 

    // Check params
    if(vms==null || vms.length ==0)
    {
        return new ArrayList<VirtualMachine>();
    }

    // Need hosts to properly calculate cpu metrics
    gatherHosts();

    // Retrieve properties from VMware on the virtual machines
    logger.info("Starting PropertyCollectorUtil.retrieveProperties");
    Hashtable[] pTables = PropertyCollectorUtil.retrieveProperties(vms, "VirtualMachine",
            new String[] {"name",
            "config.hardware.device",
            "guest.toolsStatus",
            "guest.guestId",
            "guest.net",
            "config.uuid",
            "config.template",
            "layoutEx.disk",
            "layoutEx.file",
            "runtime.powerState",
            "runtime.host",
            "config.hardware.memoryMB",
            "config.hardware.numCPU"});
    logger.info("Finished PropertyCollectorUtil.retrieveProperties");

    // Make sure we got a valid result from VMware
    if (pTables == null) 
    {
        return new ArrayList<VirtualMachine>();
    }

    // Process the property list
    for(int i=0; i<pTables.length; i++)
    {
      // Ignore virtual machine templates
      if (pTables[i].get("config.template") == true)
      {
        logger.fine("Filtering Template ("+pTables[i].get("name")+")");
      }
      else 
      {
        logger.info("Parsing ("+pTables[i].get("name")+")");
        // Add to the result set the virtual machine
        vmsList.add((VirtualMachine)vms[i]);

        // Build a hash of the virtual machine used for reporting to 6fusion
        HashMap<String, Object> vm = new HashMap<String, Object>();

        ManagedObjectReference host_ref = (ManagedObjectReference) pTables[i].get("runtime.host");
        vm.put("external_vm_id",vms[i].getMOR().get_value().toString());
        vm.put("external_host_id", host_ref.get_value().toString());
        vm.put("uuid",pTables[i].get("config.uuid"));
        vm.put("name",pTables[i].get("name"));
        vm.put("cpu_count",pTables[i].get("config.hardware.numCPU"));
        vm.put("maximum_memory",pTables[i].get("config.hardware.memoryMB"));
        vm.put("power_state",pTables[i].get("runtime.powerState").toString());
        // CPU in MHZ        
        long hz = get_host_hz((ManagedObjectReference) pTables[i].get("runtime.host"));
        vm.put("cpu_speed",hz / 1000000);
        // Determine tool status
        boolean tool_status = true;
        if (pTables[i].get("guest.toolsStatus") == "toolsNotInstalled") {
          tool_status = false;
        }
        vm.put("guest_agent",tool_status);
        // Determine 32-bit or 64-bit OS
        String guest_agent = (String) pTables[i].get("guest.guestId");
        String arch = "x32";
        if (guest_agent != null) {
          if (guest_agent.indexOf("64") > -1) {
              arch = "x64";
          }
        }
        // Build system hash
        HashMap<String, Object> system = new HashMap<String, Object>();
        system.put("architecture",arch);
        system.put("operating_system",guest_agent);
        vm.put("system",system);
        // Build Devices
        VirtualDevice[] vds =  (VirtualDevice[]) pTables[i].get("config.hardware.device");
        List<Map <String, Object>> vm_disks=new ArrayList<Map<String, Object>>();
        List<Map <String, Object>> vm_nics=new ArrayList<Map<String, Object>>();
        for(VirtualDevice vd:vds) {
          // Build disks and NICs 
          if(vd instanceof VirtualDisk) {
            HashMap<String, Object> disk_hash = get_disk((VirtualDisk) vd, pTables, i); 
            vm_disks.add(disk_hash);
          } else if ((vd instanceof VirtualPCNet32) || (vd instanceof VirtualE1000) || (vd instanceof VirtualVmxnet)) {
            HashMap<String, Object> nic_hash = get_nic((VirtualEthernetCard) vd, pTables, i);
            vm_nics.add(nic_hash);
          } 
        }
        vm.put("disks",vm_disks);
        vm.put("nics",vm_nics);
        // Add hash representation to object instance
        this.vmMap.put(vms[i].getMOR().get_value().toString(), vm);
      }
    }    
    logger.fine("Exiting VMwareAdaptor.gatherProperties(ManagedEntity[] vms)");
    // This result is mainly used for the command-line version to print the results of the API calls made to VMware
    return(vmsList);
  }

  /**
   * printVMs
   *
   * Dumps the vmMap to STDOUT 
   *
   */
  public String json()
  {   
    logger.fine("Entering VMwareAdaptor.json()");
    Gson gson = new Gson();
    String json = gson.toJson(this.vmMap);
    logger.fine("Exiting VMwareAdaptor.json()");
    return json;
  }

  /**
   * virtualMachines
   *
   * Build the Disk hash of properties
   *
   * @return List<VirtualMachine> List of virtual machines
   */
  public List<VirtualMachine>  virtualMachines()
  { 
    logger.fine("Entering virtualMachines()");
    List<VirtualMachine> vms = new ArrayList<VirtualMachine>();
    int i = 0;
    for (String moref: this.vmMap.keySet()) {
        vms.add((VirtualMachine)this.vmMap.get(moref).get("vm"));
    }
    logger.fine("Exiting VMwareAdaptor.virtualMachines()");
    return vms;
  }

  /**
   * printHosts
   *
   * Dumps the hostMap to STDOUT 
   *
   */
  public void printHosts()
  {
    logger.fine("Entering VMwareAdaptor.printHosts()");
    for (String moref: this.hostMap.keySet()) {
      for (Map.Entry<String,Object> entry : this.hostMap.get(moref).entrySet()) {
        System.out.println(moref+" "+entry.getKey()+" "+entry.getValue());
      }
    }
    logger.fine("Exiting VMwareAdaptor.printHosts()");
  }

  /**
   * get_host_hz
   *
   * Helper function for finding the hz for a Host MORef
   *
   * @param  host_mor ManagedObjectReference
   * @return hz
   */
  private long get_host_hz(ManagedObjectReference host_mor)
  {
    logger.fine("Entering VMwareAdaptor.get_host_hz(ManagedObjectReference host_mor)");
    String host_key = host_mor.get_value().toString();
    HashMap<String, Object> host_hash = this.hostMap.get(host_key);
    Long hz = (Long) host_hash.get("hz");
    logger.fine("Exiting VMwareAdaptor.get_host_hz(ManagedObjectReference host_mor))");
    return hz;
  }
  /**
   * gatherCounters 
   *
   * Populates this.counterMap
   * Key - Counter Name
   * Value - Counter ID
   */
  private void gatherCounters() throws Exception
  {
    logger.fine("Entering VMwareAdaptor.gatherCounters()");
    PerformanceManager perfMgr = this.si.getPerformanceManager();
    PerfCounterInfo[] pcis = perfMgr.getPerfCounter();
    for(int i=0; pcis!=null && i<pcis.length; i++)
    {
      String perfCounter = pcis[i].getGroupInfo().getKey() + "."
        + pcis[i].getNameInfo().getKey() + "." 
        + pcis[i].getRollupType();
      logger.fine("\nKey:" + pcis[i].getKey());
      logger.fine("PerfCounter:" + perfCounter);
      logger.fine("Level:" + pcis[i].getLevel());
      logger.fine("StatsType:" + pcis[i].getStatsType());
      logger.fine("UnitInfo:"+ pcis[i].getUnitInfo().getKey());
      this.counterMap.put(perfCounter, (Integer) pcis[i].getKey());
      this.counterIdMap.put((Integer) pcis[i].getKey(), perfCounter);
    }
    logger.fine("Exiting VMwareAdaptor.gatherCounters()");
  }
  /**
   * getCounterIds
   *
   * Build the Disk hash of properties
   *
   * @param  counter_names String[]
   * @return List<Integer> List of counter IDs
   */
  private List<Integer> getCounterIds(String[] counter_names)
  {
    logger.fine("Entering VMwareAdaptor.getCounterIds(String[] counter_names)");
    List<Integer> result = new ArrayList<Integer>();
    for ( int i=0; i < counter_names.length; i++)
    {
      Integer counterId = this.counterMap.get(counter_names[i]);
      if (counterId != null) {
        logger.finer("Found "+counter_names[i]);
        result.add(counterId);
      }
    }
    logger.fine("Exiting VMwareAdaptor.getCounterIds(String[] counter_names)");
    return result;
  }

  /**
   * gatherHosts 
   *
   * Populates this.hostMap with the hosts for a vCenter
   * Key - vCenter MORef
   * Values include name, hz, memorySize
   */
  private void gatherHosts() throws Exception
  {
    logger.fine("Entering VMwareAdaptor.gatherHosts()");
    Folder rootFolder = this.si.getRootFolder();
    ManagedEntity[] hosts = new InventoryNavigator(rootFolder).searchManagedEntities(
                    new String[][] { {"HostSystem", "name"}, }, true);
    logger.fine("\nretrieve multiple properties from multiple managed objects.");
    Hashtable[] pTables = PropertyCollectorUtil.retrieveProperties(hosts, "HostSystem",
            new String[] {"name", 
            "hardware.cpuInfo.hz",
            "hardware.memorySize"});
    for(int i=0; i<pTables.length; i++)
    {   
      HashMap<String, Object> host = new HashMap<String, Object>();
      host.put("name",pTables[i].get("name"));
      host.put("hz",pTables[i].get("hardware.cpuInfo.hz"));
      host.put("memorySize",pTables[i].get("hardware.memorySize"));
      this.hostMap.put(hosts[i].getMOR().get_value().toString(), host);
      logger.fine("host key is "+hosts[i].getMOR().get_value().toString());
    }
    logger.fine("Exiting VMwareAdaptor.gatherHosts()");
  }
  /**
   * get_disk
   *
   * Build the Disk hash of properties
   *
   * @param  vNic VirtualEthernetCard
   * @param  pTables pTables  Hashtable[]
   * @param  i int - current position in pTable
   * @return Hashmap with maximum_size, type, thin, uuid, key and usage
   */
  private HashMap<String, Object> get_disk(VirtualDisk vDisk, Hashtable[] pTables, int i)
  {
    logger.fine("Entering get_disk(VirtualDisk vDisk, Hashtable[] pTables, int i)");
    HashMap<String, Object> disk_hash = new HashMap<String, Object>();
    if (vDisk == null || pTables == null) {
      return(disk_hash);
    }
    disk_hash.put("maximum_size",(vDisk.getCapacityInKB() * VMwareAdaptor.KB) );
    disk_hash.put("controller_key",vDisk.getControllerKey());
    disk_hash.put("type","Disk");
    disk_hash.put("unit_number",vDisk.getUnitNumber());
    disk_hash.put("name",vDisk.getDeviceInfo().getLabel());
    if(vDisk.getBacking() instanceof VirtualDiskFlatVer2BackingInfo){
      VirtualDiskFlatVer2BackingInfo backing = (VirtualDiskFlatVer2BackingInfo) vDisk.getBacking();
      disk_hash.put("disk_mode",backing.getDiskMode());
      disk_hash.put("split",backing.getSplit());
      disk_hash.put("write_through",backing.getWriteThrough());
      disk_hash.put("thin",backing.getThinProvisioned());
      disk_hash.put("uuid",backing.getUuid());     
      disk_hash.put("file_name",backing.getFileName());
    } else if (vDisk.getBacking() instanceof VirtualDiskRawDiskMappingVer1BackingInfo){
      VirtualDiskRawDiskMappingVer1BackingInfo backing = (VirtualDiskRawDiskMappingVer1BackingInfo) vDisk.getBacking();
      disk_hash.put("device_name",backing.getDeviceName());
      disk_hash.put("lun_uuid",backing.getLunUuid());     
      disk_hash.put("uuid",backing.getUuid());     
    } else if (vDisk.getBacking() instanceof VirtualDiskRawDiskVer2BackingInfo){
      VirtualDiskRawDiskVer2BackingInfo backing = (VirtualDiskRawDiskVer2BackingInfo) vDisk.getBacking();
      disk_hash.put("descriptive_file_name",backing.getDescriptorFileName());
      disk_hash.put("uuid",backing.getUuid());     
    } else if (vDisk.getBacking() instanceof VirtualDiskSparseVer2BackingInfo){
      VirtualDiskSparseVer2BackingInfo backing = (VirtualDiskSparseVer2BackingInfo) vDisk.getBacking();
      disk_hash.put("disk_mode",backing.getDiskMode());
      disk_hash.put("split",backing.getSplit());
      disk_hash.put("write_through",backing.getWriteThrough());
      disk_hash.put("space_used_in_kb",backing.getSpaceUsedInKB());
      disk_hash.put("uuid",backing.getUuid());     
    } else if (vDisk.getBacking() instanceof VirtualDiskSeSparseBackingInfo){
      VirtualDiskSeSparseBackingInfo backing = (VirtualDiskSeSparseBackingInfo) vDisk.getBacking();
      disk_hash.put("disk_mode",backing.getDiskMode());
      disk_hash.put("write_through",backing.getWriteThrough());
      disk_hash.put("uuid",backing.getUuid());     
      disk_hash.put("delta_disk_format",backing.getDeltaDiskFormat());
      disk_hash.put("digest_enabled",backing.getDigestEnabled());
      disk_hash.put("grain_size",backing.getGrainSize());
    }
    disk_hash.put("key",vDisk.getKey());
    // Determine disk usage.  Usage is not considered a metric in VMware.
    long usage = 0;
    if  (pTables[i].get("layoutEx.disk") == null) {
      logger.warning("Missing layoutEx.disk ("+pTables[i].get("name")+")");
    } else {
      //   find layoutex.disk that matches the VirtualDisk.getKey()
      VirtualMachineFileLayoutExDiskLayout[] layoutexDisks = (VirtualMachineFileLayoutExDiskLayout[])pTables[i].get("layoutEx.disk");
      for (int j=0; j < layoutexDisks.length; j++) {
        VirtualMachineFileLayoutExDiskLayout diskLayout = layoutexDisks[j];
        if (diskLayout.getKey() == vDisk.getKey()) {
          //      Iterate over layoutex.disk.chain of disk units
          VirtualMachineFileLayoutExDiskUnit[] diskUnits = diskLayout.getChain();
          if (diskUnits == null) {
            logger.warning("Missing layoutEx.disk["+diskLayout.getKey()+"].chain for ("+pTables[i].get("name")+")");
          } else {
            for(int k=0; k < diskUnits.length; k++) {
              //         Find layoutex.file where getKey matches any chainfilekey     
              VirtualMachineFileLayoutExFileInfo[] layoutexFiles = (VirtualMachineFileLayoutExFileInfo[])pTables[i].get("layoutEx.file");
              if (layoutexFiles == null) {
                logger.warning("Missing layoutEx.file for ("+pTables[i].get("name")+")");
              } else {
                for (int m=0; m < layoutexFiles.length; m++) {
                  int[] filekeys = diskUnits[k].getFileKey();
                  for (int n=0; n < filekeys.length; n++) {
                    if (layoutexFiles[m].getKey() == filekeys[n]) {
                      //              Add to vdisk_files
                      usage += layoutexFiles[m].size * GB;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    disk_hash.put("usage",usage);
    logger.fine("Exiting get_disk(VirtualDisk vDisk, Hashtable[] pTables, int i)");
    return(disk_hash);
  }

  /**
   * get_nic
   *
   * Build the NIC hash of properties
   *
   * @param  vNic VirtualEthernetCard
   * @param  pTables pTables  Hashtable[]
   * @param  i int - current position in pTable
   * @return Hashmap with mac_address, name, key, uuid and ip_address
   */
  private HashMap<String, Object> get_nic(VirtualEthernetCard vNic, Hashtable[] pTables, int i)
  {
    logger.fine("Entering VMwareAdaptor.get_nic(VirtualEthernetCard vNic, Hashtable[] pTables, int i)");
    HashMap<String, Object> nic_hash = new HashMap<String, Object>();
    nic_hash.put("mac_address",vNic.getMacAddress());
    nic_hash.put("name",vNic.getDeviceInfo().getLabel());
    nic_hash.put("key",vNic.getKey());
    nic_hash.put("uuid","aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa"+vNic.getKey());
    if ((pTables[i].get("guest.net") != null) && (pTables[i].get("guest.net") instanceof GuestNicInfo[]) ){
      GuestNicInfo[] guestNicInfo = ( GuestNicInfo[]) pTables[i].get("guest.net");
      String ip_address = parse_nic_ip_address(vNic, guestNicInfo);
      nic_hash.put("ip_address", ip_address);     
    }
    logger.fine("Exiting VMwareAdaptor.get_nic(VirtualEthernetCard vNic, Hashtable[] pTables, int i)");
    return nic_hash;
  }

  /**
   * parse_nic_ip_address 
   *
   * For a given VirtualEthernetCard it will pase the Device Config info to find
   * the IP Address, if any.
   * <p>
   *
   * @param  vNic VirtualEthernetCard 
   * @param  guestNicInfo Array of GuestNicInfo to match device.config.id
   * @return String IP Address.
   */
  private String parse_nic_ip_address(VirtualEthernetCard vNic, GuestNicInfo[] guestNicInfo)
  {
    logger.fine("Entering VMwareAdaptor.parse_nic_ip_address(VirtualEthernetCard vNic, GuestNicInfo[] guestNicInfo)");
    for(int j=0; j < guestNicInfo.length; j++) {
      if (guestNicInfo[j].getDeviceConfigId() == vNic.getKey()) {
        if (guestNicInfo[j] != null) {
          if (guestNicInfo[j].getIpAddress() != null)  {
            logger.fine("Exiting VMwareAdaptor.parse_nic_ip_address(VirtualEthernetCard vNic, GuestNicInfo[] guestNicInfo)");
            return(guestNicInfo[j].getIpAddress()[0]);
          }
        }
      }
    }
    logger.fine("Exiting parse_nic_ip_address(VirtualEthernetCard vNic, GuestNicInfo[] guestNicInfo)");
    return "Unknown";
  }

  /**
   * readings
   *
   * gather all VMs and readings.  Populates this.vmMap and this.hostMap
   *
   * @param  startIso8601 String
   * @param  endIso8601 String
   */
  public void readings(String startIso8601, String endIso8601) throws Exception
  {
    logger.fine("Entering VMwareAdaptor.readings(String startIso8601, String endIso8601)");
    DateTimeFormatter parser2 = ISODateTimeFormat.dateTimeNoMillis();
    logger.info(startIso8601+" "+endIso8601);
    Calendar startTime = (Calendar) Calendar.getInstance(TimeZone.getTimeZone("GMT")).clone();
    Calendar endTime = (Calendar) Calendar.getInstance(TimeZone.getTimeZone("GMT")).clone();
    startTime.setTime(parser2.parseDateTime(startIso8601).toDate());
    endTime.setTime(parser2.parseDateTime(endIso8601).toDate());
    readings(startTime,endTime);
    logger.fine("Exiting VMwareAdaptor.readings(String startIso8601, String endIso8601)");
  }

  /**
   * readings
   *
   * gather all VMs and readings.  Populates this.vmMap and this.hostMap
   *
   * @param  startTime Calendar
   * @param  endTime Calendar
   */
  public void readings(Calendar startTime, Calendar endTime) throws Exception
  {
    logger.fine("Entering VMwareAdaptor.readings(Calendar startTime, Calendar endTime)");
    List<VirtualMachine> vms = gatherVirtualMachines();
    readings(vms,startTime, endTime);
    logger.fine("Exiting VMwareAdaptor.readings(Calendar startTime, Calendar endTime)");
  }

  /**
   * readings
   *
   * gather properties for VMs in requested List and readings.  Populates this.vmMap and this.hostMap
   *
   * @param  vms List<VirtualMachine> 
   * @param  startTime Calendar
   * @param  endTime Calendar
   */
  public void readings(List<VirtualMachine> vms, Calendar startTime, Calendar endTime) throws Exception
  {
    logger.fine("Entering VMwareAdaptor.readings(List<VirtualMachine> vms, Calendar startTime, Calendar endTime)");

    gatherCounters();
    PerfMetricId cpu_usage = new PerfMetricId();
    cpu_usage.setCounterId(this.counterMap.get("cpu.usage.average"));
    cpu_usage.setInstance("");
    
    PerfMetricId cpu_usagemhz = new PerfMetricId();
    cpu_usagemhz.setCounterId(this.counterMap.get("cpu.usagemhz.average"));
    cpu_usagemhz.setInstance("");

    PerfMetricId mem = new PerfMetricId();
    mem.setCounterId(this.counterMap.get("mem.consumed.average"));
    mem.setInstance("");

    PerfMetricId vdisk_read = new PerfMetricId();
    vdisk_read.setCounterId(this.counterMap.get("virtualDisk.read.average"));
    vdisk_read.setInstance("*");

    PerfMetricId vdisk_write = new PerfMetricId();
    vdisk_write.setCounterId(this.counterMap.get("virtualDisk.write.average"));
    vdisk_write.setInstance("*");

    PerfMetricId net_recv = new PerfMetricId();
    net_recv.setCounterId(this.counterMap.get("net.received.average"));
    net_recv.setInstance("*");

    PerfMetricId net_trans = new PerfMetricId();
    net_trans.setCounterId(this.counterMap.get("net.transmitted.average"));
    net_trans.setInstance("*");

    List<PerfQuerySpec> qSpecList = new ArrayList<PerfQuerySpec>();
    Iterator<VirtualMachine> it = vms.iterator();
    while (it.hasNext()) {
      PerfQuerySpec qSpec = new PerfQuerySpec();
      VirtualMachine vm = it.next();
      qSpec.setEntity(vm.getMOR());
      qSpec.setFormat("normal");
      qSpec.setIntervalId(300);
      qSpec.setMetricId( new PerfMetricId[] {cpu_usage,cpu_usagemhz,mem,vdisk_read,vdisk_write,vdisk_write,net_trans,net_recv});
      qSpec.setStartTime(startTime);
      qSpec.setEndTime(endTime);
      qSpecList.add(qSpec);
    }

    PerformanceManager pm = getPerformanceManager();
    PerfQuerySpec[] pqsArray = qSpecList.toArray(new PerfQuerySpec[qSpecList.size()]);
    logger.info("Start PerformanceManager.queryPerf");
    PerfEntityMetricBase[] pembs = pm.queryPerf( pqsArray);
    logger.info("Finished PerformanceManager.queryPerf");
    logger.info("Start gathering of valid timestamps");
    DateTimeFormatter fmt = ISODateTimeFormat.dateTimeNoMillis();
    String timestamp = fmt.withZone(DateTimeZone.UTC).print(endTime.getTimeInMillis());
    this.tsSet.add(timestamp);
    for(int i=0; pembs!=null && i< pembs.length; i++)
    {
      if(pembs[i] instanceof PerfEntityMetric)
      {
        parseValidTimestamps((PerfEntityMetric)pembs[i]);
      }

    }
    // Prepopulate with all timestamps
    String[] ts = this.tsSet.toArray(new String[0]);
    for (String moref: this.vmMap.keySet()) {
      HashMap<String, HashMap<String, Long>> metrics = new HashMap<String, HashMap<String, Long>>();
      for(int i=0; ts!=null && i<ts.length; i++) {
        metrics.put(ts[i], new HashMap<String, Long>()); 
      }
      this.vmMap.get(moref).put("stats",metrics);
    }
    logger.info("Finished gathering of valid timestamps");
    logger.info("Start parsing metrics");
    for(int i=0; pembs!=null && i< pembs.length; i++)
    {
      //DEBUG - printPerfMetric(pembs[i]);
      if(pembs[i] instanceof PerfEntityMetric)
      {
        String vm_mor = pembs[i].getEntity().get_value();
        HashMap<String, HashMap<String, Long>> metrics = parsePerfMetricForVM(vm_mor, (PerfEntityMetric)pembs[i]);
        this.vmMap.get(vm_mor).put("stats",metrics);
        // DEBUG - printMachineReading(vm_mor,metrics);
      }
    }
    logger.info("Finished parsing metrics");
    logger.fine("Exiting VMwareAdaptor.readings(String startIso8601, String endIso8601)");
  }

  // Gather all timestamps pulled for the metrics
  private void parseValidTimestamps(PerfEntityMetric pem)
  {
    logger.fine("Entering VMwareAdaptor.readings(String startIso8601, String endIso8601)");
    PerfSampleInfo[]  infos = pem.getSampleInfo();
    for(int i=0; infos!=null && i<infos.length; i++) {
      DateTimeFormatter fmt = ISODateTimeFormat.dateTimeNoMillis();
      String timestamp = fmt.withZone(DateTimeZone.UTC).print(infos[i].getTimestamp().getTimeInMillis());
      this.tsSet.add(timestamp);
      logger.finer("parseValidTimestmaps() found "+timestamp);
    }
    logger.fine("Exiting VMwareAdaptor.readings(List<VirtualMachine> vms, Calendar startTime, Calendar endTime)");
  
  }

  // This does one virtual machine parsing of metrics
  private HashMap<String, HashMap<String, Long>> parsePerfMetricForVM(String vm_mor, PerfEntityMetric pem)
  {
    logger.fine("Entering VMwareAdaptor.parsePerfMetricForVM(String vm_mor, PerfEntityMetric pem)");
    PerfMetricSeries[] vals = pem.getValue();
    PerfSampleInfo[]  infos = pem.getSampleInfo();
    HashMap<String, Object> vm_hash = this.vmMap.get(vm_mor);
    // Ignore compile warning
    @SuppressWarnings("unchecked")
    HashMap<String, HashMap<String, Long>> metrics = (HashMap<String, HashMap<String, Long>>)vm_hash.get("stats");
    // Prepopulate with all timestamps
    String[] ts = this.tsSet.toArray(new String[0]);
    for(int i=0; ts!=null && i<ts.length; i++) {
      metrics.put(ts[i], new HashMap<String, Long>()); 
    }
    // Fill in metrics gathered
    for(int i=0; infos!=null && i<infos.length; i++) {
      DateTimeFormatter fmt = ISODateTimeFormat.dateTimeNoMillis();
      String timestamp = fmt.withZone(DateTimeZone.UTC).print(infos[i].getTimestamp().getTimeInMillis());
      for (int j=0; vals!=null && j<vals.length; ++j){
        String counterName = this.counterIdMap.get(vals[j].getId().getCounterId());
        String instanceName = vals[j].getId().getInstance();
        String metricName = counterName;
        if (instanceName.length() > 0) {
            metricName = counterName+"."+instanceName;
        }
        if(vals[j] instanceof PerfMetricIntSeries) {
          PerfMetricIntSeries val = (PerfMetricIntSeries) vals[j];
          long[] longs = val.getValue();
          long value = longs[i];
          metrics.get(timestamp).put(metricName, value);
          logger.finer("parsePerfMetricForVM adding "+timestamp+" "+metricName+" "+value);
        } 
      }
    }
    logger.fine("Exiting VMwareAdaptor.parsePerfMetricForVM(String vm_mor, PerfEntityMetric pem)");
    return(metrics);
  }

  private void printMachineReading(String vm_mor,  HashMap<String, HashMap<String, Long>> metrics)
  {
    logger.fine("Entering VMwareAdaptor.printMachineReading(String vm_mor,  HashMap<String, HashMap<String, Long>> metrics)");
    HashMap<String, Object> machine_reading = new HashMap<String, Object>();
    System.out.println(vm_mor);
    for (String date: metrics.keySet()) {
      HashMap<String, Long> metric = metrics.get(date);
      for(String name: metric.keySet()) {
        System.out.println(date+" "+name+" "+metric.get(name) );
      }
    }
    logger.fine("Exiting VMwareAdaptor.printMachineReading(String vm_mor,  HashMap<String, HashMap<String, Long>> metrics)");
  }

  private void printPerfMetric(PerfEntityMetricBase val)
  {
    logger.fine("Entering VMwareAdaptor.printPerfMetric(PerfEntityMetricBase val)");
    String entityDesc = val.getEntity().getType() + ":" + val.getEntity().get_value();
    System.out.println("Entity:" + entityDesc);
    if(val instanceof PerfEntityMetric)
    {
      printPerfMetric((PerfEntityMetric)val);
    }
    else if(val instanceof PerfEntityMetricCSV)
    {
      printPerfMetricCSV((PerfEntityMetricCSV)val);
    }
    else
    {
      logger.severe("UnExpected sub-type of PerfEntityMetricBase.");
    }
    logger.fine("Exiting VMwareAdaptor.printPerfMetric(PerfEntityMetricBase val)");
  }

  private void printPerfMetric(PerfEntityMetric pem)
  {
    logger.fine("Entering VMwareAdaptor.printPerfMetricCSV(PerfEntityMetricCSV pems)");
    PerfMetricSeries[] vals = pem.getValue();
    PerfSampleInfo[]  infos = pem.getSampleInfo();

    System.out.println("Sampling Times and Intervales:");
    for(int i=0; infos!=null && i<infos.length; i++)
    {
        System.out.println("sample time: "+ infos[i].getTimestamp().getTime());
        System.out.println("sample interval (sec):"+ infos[i].getInterval());
    }

    System.out.println("\nSample values:");
    for(int j=0; vals!=null && j<vals.length; ++j)
    {
      String counterName = this.counterIdMap.get(vals[j].getId().getCounterId());
      System.out.println("Perf counter ID:"+ vals[j].getId().getCounterId());
      System.out.println("Perf counter Name:" + counterName);
      System.out.println("Device instance ID:"+ vals[j].getId().getInstance());
      
      if(vals[j] instanceof PerfMetricIntSeries)
      {
        PerfMetricIntSeries val = (PerfMetricIntSeries) vals[j];
        long[] longs = val.getValue();
        for(int k=0; k<longs.length; k++) 
        {
          System.out.print(longs[k] + " ");
        }
        System.out.println("Total:"+longs.length);
      }
      else if(vals[j] instanceof PerfMetricSeriesCSV)
      { // it is not likely coming here...
        PerfMetricSeriesCSV val = (PerfMetricSeriesCSV) vals[j];
        System.out.println("CSV value:" + val.getValue());
      }
    }
    logger.fine("Exiting VMwareAdaptor.printPerfMetricCSV(PerfEntityMetricCSV pems)");
  }

  private void printPerfMetricCSV(PerfEntityMetricCSV pems)
  {
    logger.fine("Entering VMwareAdaptor.printPerfMetricCSV(PerfEntityMetricCSV pems)");
      System.out.println("SampleInfoCSV:"+ pems.getSampleInfoCSV());
      PerfMetricSeriesCSV[] csvs = pems.getValue();
      for(int i=0; i<csvs.length; i++)
      {
        System.out.println("PerfCounterId:"+ csvs[i].getId().getCounterId());
        System.out.println("CSV sample values:"+ csvs[i].getValue());
      }
    logger.fine("Exiting VMwareAdaptor.printPerfMetricCSV(PerfEntityMetricCSV pems)");
  }
  /**
   * main
   *
   * Example connection to vCenter and printing out hosts and virtual machines.
   *
   */
  public static void main(String[] args) throws Exception 
  {
    logger.fine("Entering VMwareAdaptor.main()");
    if (args.length < 3) {
            System.err.println("Usage: VMwareAdaptor https://<vcenter_host>/sdk username password <startIso8601> <endIso8601>");
            System.err.println("       startIso8601/endIso8601 are optional parameters used only to pull metrics");
            System.exit(1);
    }
    VMwareAdaptor vmware_adaptor = new VMwareAdaptor(args[0],args[1],args[2]);
    if (args.length == 5) {
      vmware_adaptor.readings(args[3],args[4]);
    } else {
      vmware_adaptor.gatherVirtualMachines();
    }
    System.out.println(vmware_adaptor.json());
    System.out.println(vmware_adaptor.getAboutInfo().toString());
    System.out.println(vmware_adaptor.getStatisticLevels().toString());
    vmware_adaptor.close();
    logger.fine("Exiting VMwareAdaptor.main()");
  }
}

