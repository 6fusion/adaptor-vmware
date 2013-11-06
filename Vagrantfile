# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.define 'adaptor-vmware' do |adaptor_vmware|
    adaptor_vmware.vm.hostname = 'adaptor-vmware'
    adaptor_vmware.vm.box      = 'centos-6.3-amd64'
    adaptor_vmware.vm.box_url  = 'http://chef.6fusion.lab/centos-6.3-amd64.box'

    adaptor_vmware.vm.provider :virtualbox do |virtualbox|
      virtualbox.customize ['modifyvm', :id] + %w{--memory 1024 --ioapic on --cpus 1}
    end

    adaptor_vmware.vm.network :private_network, ip: '192.168.128.5'

    squid_installed = %x{which squid > /dev/null ; echo $?}.chomp == '0'

    adaptor_vmware.vm.provision :chef_solo do |chef|
      if squid_installed
        puts 'Using Local Squid proxy'
        chef.http_proxy  = 'http://192.168.128.1:3128'
        chef.https_proxy = 'http://192.168.128.1:3128'
        chef.add_recipe 'proxy'
      end

      chef.cookbooks_path = %w{../chef-server/cookbooks}
      chef.roles_path     = '../chef-server/roles'
      chef.data_bags_path = '../chef-server/data_bags'
      # for CRM support
      chef.add_role 'adaptor_vmware'
      chef.add_recipe 'instrumentation'
      chef.data_bags_path = '../chef-server/data_bags'
      chef.json           = {
          'proxy'     => {
              'http'  => '',
              'https' => ''
          },
          :fqdn       => 'adaptor-vmware.local',
          :hosts      => {
              '192.168.128.1' => %w{control-room.6fusion.com console api.6fusion.com host}
          },
          :java       => { :opts => '-Xms1024m -Xmx1024m' },
          :autossh    => {
              :sshport    => '2222',
              :remotehost => 'console'
          },
          '6fusion'   => {
              :console => 'http://192.168.64.2:8080'
          },
          'torquebox' => {
              'version' => '2.3.2'
          }
      }
    end

  end
end


