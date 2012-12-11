/**
 * @author      Geoff Corey <gcorey@6fusion.com>
 * @version     0.1                 
 * @since       2012-12-09        
 */
import java.net.MalformedURLException;
import java.net.URL;
import java.rmi.RemoteException;
import java.util.*;
import java.lang.Math;
// import net.sf.json.JSONObject;

import com.vmware.vim25.*;
import com.vmware.vim25.mo.*;
import com.vmware.vim25.mo.util.*;
/**
 * Sample code to show how to use the Managed Object APIs.
 * @author Steve JIN (sjin@vmware.com)
 */

public class VMwareInventory 
{
    private ServiceInstance si = null;
    private Folder rootFolder = null;
    // Hash of host-morefID to host hash of attributes / values
    public HashMap<String, HashMap<String, Object>> hostMap = new HashMap<String, HashMap<String, Object>>();
    // Hash of vm-UUID to vm hash of attributes / values
    public HashMap<String, HashMap<String, Object>> vmMap = new HashMap<String, HashMap<String, Object>>();
    // Hash of PerfCounter name to Counter ID
    public HashMap<String, Integer> counterMap = new HashMap<String, Integer>();
    // Utility Constants
    public static long KB = 1024;
    public static double MB = Math.pow(1024,2);
    public static double GB = Math.pow(1024,3);
    public static double TB = Math.pow(1024,4);

    /**
 * Short one line description.                           (1)
 *
 * Longer description. If there were any, it would be    [2]
 * here.
 * <p>
 * And even more explanations to follow in consecutive
 * paragraphs separated by HTML paragraph breaks.
 *
 * @param  variable Description text text text.          (3)
 * @return Description text text text.
 */
    public VMwareInventory(String url, String username, String password ) throws Exception
    {
        ServiceInstance si = new ServiceInstance(new URL(url), username, password, true);
        this.si = si;
        gatherCounters();
        gatherVirtualMachines();
    }

    public void close()
    {
      this.si.getServerConnection().logout();
    }

    public Calendar currentTime() throws Exception
    {
        return this.si.currentTime();
    }
    public PerformanceManager getPerformanceManager()
    {
        return si.getPerformanceManager();
    }
    /**
     * main
     *
     * Example connection to vCenter and printing out hosts and virtual machines.
     *
     */
    public static void main(String[] args) throws Exception
    {
        if (args.length != 3) {
                System.err.println("Usage: VMwareInventory https://10.10.10.10/sdk username password ");
                System.exit(1);
        }

        VMwareInventory vmware_inventory = new VMwareInventory(args[0],args[1],args[2]);
        vmware_inventory.printHosts();
        vmware_inventory.printVMs();
        vmware_inventory.gatherCounters();
        String[] counterNames = { "cpu.usage.average",
                        "cpu.usagemhz.average",
                        "mem.consumed.average",
                        "virtualDisk.read.average",
                        "virtualDisk.write.average",
                        "net.received.average",
                        "net.transmitted.average"};
        System.out.println("pants"+vmware_inventory.counterMap);
        //List<Integer> counterIds = vmware_inventory.getCounterIds(counterNames);

        Calendar curTime = vmware_inventory.currentTime();

        PerfMetricId cpu_usage = new PerfMetricId();
        cpu_usage.setCounterId(vmware_inventory.counterMap.get("cpu.usage.average"));
        cpu_usage.setInstance("");
        
        PerfMetricId cpu_usagemhz = new PerfMetricId();
        cpu_usagemhz.setCounterId(vmware_inventory.counterMap.get("cpu.usagemhz.average"));
        cpu_usagemhz.setInstance("");

        PerfMetricId mem = new PerfMetricId();
        mem.setCounterId(vmware_inventory.counterMap.get("mem.consumed.average"));
        mem.setInstance("");

        PerfMetricId vdisk_read = new PerfMetricId();
        vdisk_read.setCounterId(vmware_inventory.counterMap.get("virtualDisk.read.average"));
        vdisk_read.setInstance("*");

        PerfMetricId vdisk_write = new PerfMetricId();
        vdisk_write.setCounterId(vmware_inventory.counterMap.get("virtualDisk.write.average"));
        vdisk_write.setInstance("*");

        PerfMetricId net_recv = new PerfMetricId();
        net_recv.setCounterId(vmware_inventory.counterMap.get("net.received.average"));
        net_recv.setInstance("*");

        PerfMetricId net_trans = new PerfMetricId();
        net_trans.setCounterId(vmware_inventory.counterMap.get("net.transmitted.average"));
        net_trans.setInstance("*");

        //System.out.println("donut"+counterIds);
        List<VirtualMachine> vms = vmware_inventory.virtualMachines();
        System.out.println("pizza"+vms);

        List<PerfQuerySpec> qSpecList = new ArrayList<PerfQuerySpec>();
        Iterator it = vms.iterator();
        while (it.hasNext()) {
            PerfQuerySpec qSpec = new PerfQuerySpec();
            VirtualMachine vm = (VirtualMachine)it.next();
            qSpec.setEntity(vm.getMOR());
            qSpec.setFormat("normal");
            qSpec.setIntervalId(300);
            qSpec.setMetricId( new PerfMetricId[] {cpu_usage,cpu_usagemhz,mem,vdisk_read,vdisk_write,vdisk_write,net_trans});

            Calendar startTime = (Calendar) curTime.clone();
            startTime.roll(Calendar.MINUTE, -10);
            System.out.println("start:" + startTime.getTime());
            qSpec.setStartTime(startTime);

            Calendar endTime = (Calendar) curTime.clone();
            endTime.roll(Calendar.MINUTE, -5);
            System.out.println("end:" + endTime.getTime());
            qSpec.setEndTime(endTime);
            qSpecList.add(qSpec);
        }

        PerformanceManager pm = vmware_inventory.getPerformanceManager();
        PerfQuerySpec[] pqsArray = qSpecList.toArray(new PerfQuerySpec[qSpecList.size()]);
        PerfEntityMetricBase[] pembs = pm.queryPerf( pqsArray);
        System.out.println(pembs);
        for(int i=0; pembs!=null && i< pembs.length; i++)
        {
            vmware_inventory.printPerfMetric(pembs[i]);
        }
        vmware_inventory.close();
    }

    void printPerfMetric(PerfEntityMetricBase val)
    {
        String entityDesc = val.getEntity().getType() 
            + ":" + val.getEntity().get_value();
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
          System.out.println("UnExpected sub-type of " +
                "PerfEntityMetricBase.");
        }
    }

    void printPerfMetric(PerfEntityMetric pem)
    {
        PerfMetricSeries[] vals = pem.getValue();
        PerfSampleInfo[]  infos = pem.getSampleInfo();

        System.out.println("Sampling Times and Intervales:");
        for(int i=0; infos!=null && i<infos.length; i++)
        {
            System.out.println("sample time: " 
              + infos[i].getTimestamp().getTime());
            System.out.println("sample interval (sec):" 
              + infos[i].getInterval());
        }

        System.out.println("\nSample values:");
        for(int j=0; vals!=null && j<vals.length; ++j)
        {
          System.out.println("Perf counter ID:" 
              + vals[j].getId().getCounterId());
          System.out.println("Device instance ID:" 
              + vals[j].getId().getInstance());
          
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
    }

    void printPerfMetricCSV(PerfEntityMetricCSV pems)
    {
        System.out.println("SampleInfoCSV:" 
            + pems.getSampleInfoCSV());
        PerfMetricSeriesCSV[] csvs = pems.getValue();
        for(int i=0; i<csvs.length; i++)
        {
          System.out.println("PerfCounterId:" 
              + csvs[i].getId().getCounterId());
          System.out.println("CSV sample values:" 
              + csvs[i].getValue());
        }
    }
    /**
     * gatherVirtualMachines
     *
     * Populates hostMap and vmMap.
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
     *        "cpu_speed": 2666
     *    }
     * }
     * vmMap Key:    VirtualMachien MORef
     * vmMap Values: uuid, name, cpu_count, cpu_speed, maximum_memory, guest_agent architecture,
     *               operating_system, power_state, disks and nics
     */
    public void gatherVirtualMachines() throws Exception
    {
        Folder rootFolder = this.si.getRootFolder();
        ManagedEntity[] vms = new InventoryNavigator(rootFolder).searchManagedEntities("VirtualMachine");
        
        if(vms==null || vms.length ==0)
        {
            return;
        }
        gatherHosts();

        Hashtable[] pTables = PropertyCollectorUtil.retrieveProperties(vms, "VirtualMachine",
                new String[] {"name",
                "config.hardware.device",
                "guest.toolsStatus",
                "guest.guestId",
                "guest.net",
                "config.uuid",
                "layoutEx.disk",
                "layoutEx.file",
                "runtime.powerState",
                "runtime.host",
                "config.hardware.memoryMB",
                "config.hardware.numCPU"});
        for(int i=0; i<pTables.length; i++)
        {
            HashMap<String, Object> vm = new HashMap<String, Object>();
            vm.put("vm",vms[i]);
            vm.put("uuid",pTables[i].get("config.uuid"));
            vm.put("name",pTables[i].get("name"));
            vm.put("cpu_count",pTables[i].get("config.hardware.numCPU"));
            
            long hz = get_host_hz((ManagedObjectReference) pTables[i].get("runtime.host"));
            vm.put("cpu_speed",hz / 1000000);

            vm.put("maximum_memory",pTables[i].get("config.hardware.memoryMB"));
            boolean tool_status = true;
            if (pTables[i].get("guest.toolsStatus") == "toolsNotInstalled") {
                tool_status = false;
            }
            vm.put("guest_agent",tool_status);
            String guest_agent = (String) pTables[i].get("guest.guestId");
            String arch = "x32";
            if (guest_agent != null) {
                if (guest_agent.indexOf("64") > -1) {
                    arch = "x64";
                }
            }
            HashMap<String, Object> system = new HashMap<String, Object>();
            system.put("architecture",arch);
            system.put("operating_system",guest_agent);
            vm.put("system",system);
            vm.put("power_state",pTables[i].get("runtime.powerState").toString());
            VirtualDevice[] vds =  (VirtualDevice[]) pTables[i].get("config.hardware.device");
            List<Map <String, Object>> vm_disks=new ArrayList<Map<String, Object>>();
            List<Map <String, Object>> vm_nics=new ArrayList<Map<String, Object>>();
            for(VirtualDevice vd:vds) {
                // if virtual disk then
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
            this.vmMap.put(vms[i].getMOR().get_value().toString(), vm);
        }    
    }

    /**
     * printVMs
     *
     * Dumps the vmMap to STDOUT 
     *
     */
    public void printVMs()
    {   int i = 0;
        for (String moref: this.vmMap.keySet()) {
            i++;
            String comma = "";
            System.out.print(moref+" : { ");
            for (Map.Entry<String,Object> entry : this.vmMap.get(moref).entrySet()) {
                System.out.println(comma);
                System.out.print(entry.getKey()+" : "+entry.getValue());
                comma=",";
            }
            System.out.println("");
            System.out.println("}");
        }
        System.out.println("Total # of VMs "+i);
    }

    public List<VirtualMachine>  virtualMachines()
    { 
        List<VirtualMachine> vms = new ArrayList<VirtualMachine>();
        int i = 0;
        for (String moref: this.vmMap.keySet()) {
            vms.add((VirtualMachine)this.vmMap.get(moref).get("vm"));
        }
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
        for (String moref: this.hostMap.keySet()) {
            for (Map.Entry<String,Object> entry : this.hostMap.get(moref).entrySet()) {
                System.out.println(moref+" "+entry.getKey()+" "+entry.getValue());
            }
        }
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
        String host_key = host_mor.get_value().toString();
        HashMap<String, Object> host_hash = this.hostMap.get(host_key);
        Long hz = (Long) host_hash.get("hz");
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

        PerformanceManager perfMgr = this.si.getPerformanceManager();
        PerfCounterInfo[] pcis = perfMgr.getPerfCounter();
        for(int i=0; pcis!=null && i<pcis.length; i++)
        {
            String perfCounter = pcis[i].getGroupInfo().getKey() + "."
              + pcis[i].getNameInfo().getKey() + "." 
              + pcis[i].getRollupType();
        /*
            System.out.println("\nKey:" + pcis[i].getKey());
            System.out.println("PerfCounter:" + perfCounter);
            System.out.println("Level:" + pcis[i].getLevel());
            System.out.println("StatsType:" + pcis[i].getStatsType());
            System.out.println("UnitInfo:" 
              + pcis[i].getUnitInfo().getKey());
        */
            this.counterMap.put(perfCounter, (Integer) pcis[i].getKey());
        }
    }

    private List<Integer> getCounterIds(String[] counter_names)
    {
        List<Integer> result = new ArrayList<Integer>();
        for ( int i=0; i < counter_names.length; i++)
        {
            Integer counterId = this.counterMap.get(counter_names[i]);
            if (counterId != null) {
                System.out.println("Found "+counter_names[i]);
                result.add(counterId);
            }
        }
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
        System.out.println("\n============ Hosts ============");
        Folder rootFolder = this.si.getRootFolder();
        ManagedEntity[] hosts = new InventoryNavigator(rootFolder).searchManagedEntities(
                        new String[][] { {"HostSystem", "name"}, }, true);
        // for(int i=0; i<hosts.length; i++)
        // {
           //          System.out.println("host["+i+"]=" + hosts[i].getName());
        // }
        System.out.println("\nretrieve multiple properties from multiple managed objects.");
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
            System.out.println("host key is "+hosts[i].getMOR().get_value().toString());
        }
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
        HashMap<String, Object> disk_hash = new HashMap<String, Object>();
        disk_hash.put("maximum_size",(vDisk.getCapacityInKB() * VMwareInventory.KB) / VMwareInventory.GB);
        disk_hash.put("type","Disk");
        if(vDisk.getBacking() instanceof VirtualDiskFlatVer2BackingInfo){
            VirtualDiskFlatVer2BackingInfo rdmBaking = (VirtualDiskFlatVer2BackingInfo) vDisk.getBacking();
            disk_hash.put("thin",rdmBaking.getThinProvisioned());
            disk_hash.put("uuid",rdmBaking.getUuid());     
        } 
        disk_hash.put("key",vDisk.getKey());
        // Determine disk usage.  Usage is not considered a metric in VMware.
        long usage = 0;
        if  (pTables[i].get("layoutEx.disk") != null) {
            //   find layoutex.disk that matches the VirtualDisk.getKey()
            VirtualMachineFileLayoutExDiskLayout[] layoutexDisks = (VirtualMachineFileLayoutExDiskLayout[])pTables[i].get("layoutEx.disk");
            for (int j=0; j < layoutexDisks.length; j++) {
                VirtualMachineFileLayoutExDiskLayout diskLayout = layoutexDisks[j];
                if (diskLayout.getKey() == vDisk.getKey()) {
                    //      Iterate over layoutex.disk.chain of disk units
                    VirtualMachineFileLayoutExDiskUnit[] diskUnits = diskLayout.getChain();
                    for(int k=0; k < diskUnits.length; k++) {
                        //         Find layoutex.file where getKey matches any chainfilekey     
                        VirtualMachineFileLayoutExFileInfo[] layoutexFiles = (VirtualMachineFileLayoutExFileInfo[])pTables[i].get("layoutEx.file");
                        for (int m=0; m < layoutexFiles.length; m++) {
                            int[] filekeys = diskUnits[k].getFileKey();
                            for (int n=0; n < filekeys.length; n++) {
                                if (layoutexFiles[m].getKey() == filekeys[n]) {
                                    //              Add to vdisk_files
                                    usage += layoutexFiles[m].size;
                                }
                            }
                        }
                    }
                }
            }
        }
        disk_hash.put("usage",usage);
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
        for(int j=0; j < guestNicInfo.length; j++) {
            if (guestNicInfo[j].getDeviceConfigId() == vNic.getKey()) {
                if (guestNicInfo[j] != null) {
                    if (guestNicInfo[j].getIpAddress() != null)  {
                        return(guestNicInfo[j].getIpAddress()[0]);
                    }
                }
            }
        }
        return "Unknown";
    }
}

