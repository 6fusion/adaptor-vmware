#!/bin/bash

function message {
dialog --colors --msgbox "$1" 0 0
}

function control_c {
  message "Aborted"
  reset
}

export LANG=en_US.UTF-8

VERSION=$(cat /var/6fusion/adaptor-vmware/current/VERSION)

choice=0
while [ $choice != "quit" ]
do
  choice=$(DIALOGRC="/etc/dialogrc.menu" dialog --title "6fusion.com" \
  --menu "Configure Adaptor (VMware v. $VERSION)" 8 50 0 \
   1 "Change Password" \
   2 "Network Configuration" \
   3 "Proxy and NTP Configuration" \
   4 "Reboot Appliance" \
   5 "Quit" \
   3>&1 1>&2 2>&3)
  clear
  case $choice in
   1)
     trap control_c SIGINT
     passwd
     trap - SIGINT
   ;;
   2)
    if [ -f /var/6fusion/adaptor-vmware/shared/network ]
    then
      sudo system-config-network-cmd -c --file=/var/6fusion/adaptor-vmware/shared/network
    fi
    sudo system-config-network-tui
    sudo system-config-network-cmd > /var/6fusion/adaptor-vmware/shared/network
    sudo /etc/init.d/network restart
   ;;
   3)
    source /etc/profile.d/proxy.sh
    ssh_proxy=$(grep ProxyCommand /etc/ssh/ssh_config | cut -d" " -f3,4)
    ntp_server=$(egrep "server (.+) iburst" /etc/ntp.conf | cut -d" " -f2)
    output=$(dialog --separator \| --mixedform "Proxy and NTP Configuration" 16 70 0 \
          "HTTP Proxy"  1 1 "${http_proxy}"             1 20 80 0 0 \
          "HTTPS Proxy" 3 1 "${https_proxy}"            3 20 80 0 0 \
          "No Proxy"    5 1 "${no_proxy:-localhost}"    5 20 80 0 0 \
          "NTP server"  7 1 "${ntp_server}"             7 20 80 0 0 \
           3>&1 1>&2 2>&3)
    if [ "$?" = "0" ]
    then
      mapfile -t options < <(echo $output | sed -e "s/|/\n/g")
      echo -e "export http_proxy=${options[0]}\nexport https_proxy=${options[1]}\nexport no_proxy=${options[2]}" > /etc/profile.d/proxy.sh
      source /etc/profile.d/proxy.sh
      if ! grep -qe "^options single-request-reopen" /etc/resolv.conf; then
        echo "options single-request-reopen" | sudo tee -a /etc/resolv.conf > /dev/null
      fi
      sudo restart torquebox
      if [ "${options[4]}" != "${ntp_server}" ]; then
        sudo sed -i "s/${ntp_server//./\\.}/${options[4]}/g" /etc/ntp.conf
        sudo /etc/init.d/ntpd restart
      fi
      message "Proxies Configured"
    fi
    ;;
   99)
    source /etc/profile.d/proxy.sh
    clear
    echo "Performing Connectivity Tests..."
    cd /var/6fusion/adaptor-vmware/current/lib && ./preflight.rb
    echo
    read -p "Press any key to continue... " -n1 -s
   ;;
   4)
    dialog --defaultno --yesno "Are you sure you want to reboot?" 5 40
    if [ "$?" = "0" ]
    then
      clear
      choice="quit"
      sudo /usr/bin/reboot
    fi
   ;;
   *)
    choice="quit"
   ;;
  esac
done
