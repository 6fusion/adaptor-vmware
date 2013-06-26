# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
  config.vm.box     = "centos-6.3-amd64"
  config.vm.box_url = "http://chef.6fusion.lab:4000/centos-6.3-amd64.box"
  config.vm.forward_port 8080, 8085
  config.vm.forward_port 22, 2225
  config.vm.customize ['modifyvm', :id] + %w{--memory 1024 --ioapic on --cpus 1}

  squid_installed = %x{which squid > /dev/null ; echo $?}.chomp == "0"
  local_ip = `ifconfig | egrep "inet (.+) netmask.+broadcast" | cut -d" " -f2`.chomp
  config.vm.provision :chef_solo do |chef|

    if squid_installed
      puts "Using Local Squid proxy"
      chef.http_proxy  = "http://#{local_ip}:3128"
      chef.https_proxy = "http://#{local_ip}:3128"
      chef.add_recipe 'proxy'
    end

    chef.cookbooks_path = "../chef-server/cookbooks"
    chef.roles_path     = "../chef-server/roles"
    chef.data_bags_path = "../chef-server/data_bags"
    chef.add_role "adaptor_vmware"


    # You may also specify custom JSON attributes:
    chef.json = {
        'proxy'   => {
            'http'  => "http://#{local_ip}:3128",
            'https' => "http://#{local_ip}:3128"
        },
        fqdn: 'adaptor-vmware.local'
    }
  end
end



