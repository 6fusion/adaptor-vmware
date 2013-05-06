# this is a vm in the lab that is used to export OVAs
server '10.27.5.61', :app


namespace :ova do
  task :cleanup, roles: :app do
    ENV['USER'] = "root"
    set :user, "root"
    eth0 = <<-EOF
DEVICE=eth0
BOOTPROTO=dhcp
NM_CONTROLLED=no
ONBOOT=yes
TYPE=Ethernet
    EOF
    put eth0, "/etc/sysconfig/network-scripts/ifcfg-eth0"
    put "NETWORKING=yes\nHOSTNAME=localhost", "/tmp/etc/sysconfig/network"
    run "rm /etc/udev/rules.d/70-persistent-net.rules"
    run "rm #{shared_path}/data/*"
    run "rm /var/log/torquebox/*"
    change_password('deploy')
    change_password('root')
    run "halt"
  end
end
