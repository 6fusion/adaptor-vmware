import java.net.MalformedURLException;
import java.net.URL;
import java.rmi.RemoteException;
import java.util.Hashtable;
import java.util.HashMap;
import java.util.Map;
import java.util.List;
import java.util.ArrayList;

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
    private HashMap<String, HashMap<String, Object>> hostMap = new HashMap<String, HashMap<String, Object>>();
    // Hash of vm-UUID to vm hash of attributes / values
    private HashMap<String, HashMap<String, Object>> vmMap = new HashMap<String, HashMap<String, Object>>();
    public static long KB = 1024;
    public static long MB = 1024^2;
    public static long GB = 1024^3;
    public static long TB = 1024^4;
    public VMwareInventory(ServiceInstance si ) throws Exception
    {
        this.si = si;
        gatherHosts();
        gatherVirtualMachines();
    }

    public static void main(String[] args) throws Exception
    {

        // ServiceInstance si = new ServiceInstance(new URL("https://vcenter5.6fusion.gin/sdk"), "Administrator", "7u8i&U*I", true);
        // ServiceInstance si = new ServiceInstance(new URL("https://stress-vcenter.6fusion.lab/sdk"), "Administrator", "1q2w!Q@W", true);
        ServiceInstance si = new ServiceInstance(new URL("https://192.168.221.10/sdk"), "gcorey", "dontknow", true);


        VMwareInventory vmware_inventory = new VMwareInventory(si);
        vmware_inventory.printHosts();
        vmware_inventory.printVMs();
        si.getServerConnection().logout();
    }

    public void gatherVirtualMachines() throws Exception
    {
        
        Folder rootFolder = this.si.getRootFolder();
        ManagedEntity[] vms = new InventoryNavigator(rootFolder).searchManagedEntities("VirtualMachine");
        
        if(vms==null || vms.length ==0)
        {
            return;
        }
        // VirtualMachine vm = (VirtualMachine) vms[0];
        
        // System.out.println("retrieve a property from a single managed object.");
        // VirtualMachineToolsStatus status = (VirtualMachineToolsStatus) vm.getPropertyByPath("guest.toolsStatus");
        // System.out.println("toolStatus:" + status);
        
        // System.out.println("\nretrieve multiple properties from a single managed object.");
        // Hashtable props = vm.getPropertiesByPaths(new String[] {"name", 
        //         "config.cpuFeatureMask",
        //         "config.hardware.device",
        //         "guest.toolsStatus",
        //         "guest.guestId",
        //         "config.uuid",
        //         "runtime.powerState",
        //         "config.hardware.memoryMB",
        //         "config.hardware.numCPU"});
        // System.out.println(vm);
        // System.out.println(props);
        
        System.out.println("\nretrieve multiple properties from multiple managed objects.");
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
            vm.put("uuid",pTables[i].get("config.uuid"));
            vm.put("name",pTables[i].get("name"));
            vm.put("cpu_count",pTables[i].get("config.hardware.numCPU"));
            
            ManagedObjectReference host_mor = (ManagedObjectReference)pTables[i].get("runtime.host");
            String host_key = host_mor.get_value().toString();
            System.out.println("looking up "+host_key);
            HashMap<String, Object> host_hash = (HashMap<String, Object>) this.hostMap.get(host_key);
            long hz = (long) host_hash.get("hz");
            vm.put("cpu_speed",hz / 1000000);

            vm.put("maximum_memory",pTables[i].get("config.hardware.memoryMB"));
            boolean tool_status = true;
            if (pTables[i].get("guest.toolsStatus") == "toolsNotInstalled") {
                tool_status = false;
            }
            vm.put("guest_agent",tool_status);
            String guest_agent = (String) pTables[i].get("guest.guestId");
            boolean x64_arch = false;
            if (guest_agent != null) {
                if (guest_agent.indexOf("64") > -1) {
                    x64_arch = true;
                }
            }
            vm.put("architecture",x64_arch);
            vm.put("operating_system",guest_agent);
            vm.put("power_state",pTables[i].get("runtime.powerState"));
            VirtualDevice[] vds =  (VirtualDevice[]) pTables[i].get("config.hardware.device");
            List<Map> vm_disks=new ArrayList<Map>();
            for(VirtualDevice vd:vds) {
                // if virtual disk then
                if(vd instanceof VirtualDisk) {
                    HashMap<String, Object> disk_hash = new HashMap<String, Object>();
                    VirtualDisk vDisk = (VirtualDisk) vd;
                    disk_hash.put("maximum_size",vDisk.getCapacityInKB() * this.KB / this.GB);
                    disk_hash.put("type","Disk");
                    if(vDisk.getBacking() instanceof VirtualDiskFlatVer2BackingInfo){
                        VirtualDiskFlatVer2BackingInfo rdmBaking = (VirtualDiskFlatVer2BackingInfo) vDisk.getBacking();
                        System.out.println("getThinProvisioned="+rdmBaking.getThinProvisioned());
                        System.out.println("getUuid="+rdmBaking.getUuid());                   
                        disk_hash.put("thin",rdmBaking.getThinProvisioned());
                        disk_hash.put("uuid",rdmBaking.getUuid());     
                    } 
                    disk_hash.put("key",vd.getKey());
                    vm_disks.add(disk_hash);
                    if  (pTables[i].get("layoutEx.disk") != null) {
                        //   find layoutex.disk that matches the VirtualDisk.getKey()
                        VirtualMachineFileLayoutExDiskLayout[] layoutexDisks = (VirtualMachineFileLayoutExDiskLayout[])pTables[i].get("layoutEx.disk");
                        for (int j=0; j < layoutexDisks.length; j++) {
                            VirtualMachineFileLayoutExDiskLayout diskLayout = layoutexDisks[j];
                            if (diskLayout.getKey() == vd.getKey()) {
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
                                                System.out.println("machinedisk.files="+layoutexFiles[m]);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                } else if ((vd instanceof VirtualPCNet32) || (vd instanceof VirtualE1000) || (vd instanceof VirtualVmxnet)) {
                    VirtualEthernetCard vNic = (VirtualEthernetCard) vd;
                    printNic(vNic);
                    if ((pTables[i].get("guest.net") != null) && (pTables[i].get("guest.net") instanceof GuestNicInfo[]) ){
                        System.out.println(pTables[i].get("guest.net").toString());
                        System.out.println(pTables[i].get("guest.net").getClass().toString());
                        GuestNicInfo[] guestNicInfo = ( GuestNicInfo[]) pTables[i].get("guest.net");
                        for(int j=0; j < guestNicInfo.length; j++) {
                            if (guestNicInfo[j].getDeviceConfigId() == vNic.getKey()) {
                                if (guestNicInfo[j] != null) {
                                    if (guestNicInfo[j].getIpAddress() != null)  {
                                        System.out.println(guestNicInfo[j].getIpAddress().length);
                                        System.out.println("IP Address="+guestNicInfo[j].getIpAddress()[0]);
                                    }
                                }
                            }

                        }
                    }
                } //else {
                  //  System.out.format("virtualDevice:%s%n",vd.getClass().getName());
                //}
            }
            vm.put("disks",vm_disks);
            this.vmMap.put(vms[i].getMOR().get_value().toString(), vm);
            System.out.println("# of VMs="+i);
        }    
        System.out.println("============ Data Centers ============");
            ManagedEntity[] dcs = new InventoryNavigator(rootFolder).searchManagedEntities(
                      new String[][] { {"Datacenter", "name" }, }, true);
        for(int i=0; i<dcs.length; i++)
        {
                System.out.println("Datacenter["+i+"]=" + dcs[i].getName());
        }
            
  
  
    }
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

    public void printVMs()
    {
        for (String moref: this.vmMap.keySet()) {
            for (Map.Entry<String,Object> entry : this.vmMap.get(moref).entrySet()) {
                System.out.println(moref+" "+entry.getKey()+" "+entry.getValue());
            }
        }
    }

    public void printHosts()
    {
        for (String moref: this.hostMap.keySet()) {
            for (Map.Entry<String,Object> entry : this.hostMap.get(moref).entrySet()) {
                System.out.println(moref+" "+entry.getKey()+" "+entry.getValue());
            }
        }
    }

    public static void printNic(VirtualEthernetCard vNic) throws Exception {
        System.out.println("getAddressType="+vNic.getAddressType());
        System.out.println("getMacAddress="+vNic.getMacAddress());
        System.out.println("getLabel="+vNic.getDeviceInfo().getLabel());
        System.out.println("getKey="+vNic.getKey());
    }

}

