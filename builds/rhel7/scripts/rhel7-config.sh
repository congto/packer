#!/bin/bash
# Prepare RHEL 7 template for vSphere cloning
# @author Michael Poore
# @website https://blog.v12n.io

## Set required environment variables
export RHSM_USER
export RHSM_PASS

# ## Disable IPv6
echo ' - Disabling IPv6 in grub ...'
sudo sed -i 's/quiet"/quiet ipv6.disable=1"/' /etc/default/grub
sudo grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg &>/dev/null

## Register with RHSM
echo ' - Registering with RedHat Subscription Manager ...'
sudo subscription-manager register --username $RHSM_USER --password $RHSM_PASS --auto-attach &>/dev/null

## Apply updates
echo ' - Applying package updates ...'
sudo yum update -y -q &>/dev/null

## Install core packages
echo ' - Installing additional packages ...'
sudo yum install -y -q https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &>/dev/null
# sudo yum install -y -q ca-certificates &>/dev/null
sudo yum install -y -q cloud-init perl python3 python-pip openssl cloud-utils-growpart gdisk &>/dev/null

## Adding additional repositories
echo ' - Adding repositories ...'
# sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo &>/dev/null

## Cleanup yum
echo ' - Clearing yum cache ...'
sudo yum clean all &>/dev/null

## Configure SSH server
echo ' - Configuring SSH server daemon ...'
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
sudo sed -i "s/.*PubkeyAuthentication.*/PubkeyAuthentication no/g" /etc/ssh/sshd_config
sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config

# ## Create Ansible user
# echo ' - Creating local user for Ansible integration ...'
# sudo groupadd REPLACEWITHANSIBLEUSERNAME
# sudo useradd -g REPLACEWITHANSIBLEUSERNAME -G wheel -m -s /bin/bash REPLACEWITHANSIBLEUSERNAME
# echo REPLACEWITHANSIBLEUSERNAME:$(openssl rand -base64 14) | sudo chpasswd
# sudo mkdir /home/REPLACEWITHANSIBLEUSERNAME/.ssh
# sudo tee /home/REPLACEWITHANSIBLEUSERNAME/.ssh/authorized_keys >/dev/null << EOF
# REPLACEWITHANSIBLEUSERKEY
# EOF
# sudo chown -R REPLACEWITHANSIBLEUSERNAME:REPLACEWITHANSIBLEUSERNAME /home/REPLACEWITHANSIBLEUSERNAME/.ssh
# sudo chmod 700 /home/REPLACEWITHANSIBLEUSERNAME/.ssh
# sudo chmod 600 /home/REPLACEWITHANSIBLEUSERNAME/.ssh/authorized_keys

# ## Install trusted SSL CA certificates
# echo ' - Installing trusted SSL CA certificates ...'
# pkiServer="REPLACEWITHPKISERVER"
# pkiCerts=("root.crt" "issuing.crt")
# cd /etc/pki/ca-trust/source/anchors
# for cert in ${pkiCerts[@]}; do
    # sudo wget -q $pkiServer/$cert
# done
# sudo update-ca-trust extract

## Configure cloud-init
echo ' - Installing cloud-init ...'
sudo touch /etc/cloud/cloud-init.disabled
sudo sed -i 's/disable_root: 1/disable_root: 0/g' /etc/cloud/cloud.cfg
sudo sed -i 's/^ssh_pwauth:   0/ssh_pwauth:   1/g' /etc/cloud/cloud.cfg
sudo sed -i -e 1,3d /etc/cloud/cloud.cfg
sudo sed -i "s/^disable_vmware_customization: false/disable_vmware_customization: true/" /etc/cloud/cloud.cfg
sudo sed -i "/disable_vmware_customization: true/a\\\nnetwork:\n  config: disabled" /etc/cloud/cloud.cfg
sudo sed -i "s@^[a-z] /tmp @# &@" /usr/lib/tmpfiles.d/tmp.conf
sudo sed -i "/^After=vgauthd.service/a After=dbus.service" /usr/lib/systemd/system/vmtoolsd.service
sudo sed -i '/^disable_vmware_customization: true/a\datasource_list: [OVF]' /etc/cloud/cloud.cfg

sudo tee /etc/cloud/runonce.sh >/dev/null << RUNONCE
#!/bin/bash
# Runonce script for cloud-init on vSphere
# @author Michael Poore
# @website https://blog.v12n.io

## Enable cloud-init
sudo rm -f /etc/cloud/cloud-init.disabled
## Execute cloud-init
sudo cloud-init init
sleep 20
sudo cloud-init modules --mode config
sleep 20
sudo cloud-init modules --mode final
## Mark cloud-init as complete
sudo touch /etc/cloud/cloud-init.disabled
sudo touch /tmp/cloud-init.complete
sudo crontab -r
RUNONCE
sudo chmod +rx /etc/cloud/runonce.sh
echo "$(echo '@reboot ( sleep 30 ; sh /etc/cloud/runonce.sh )' ; crontab -l)" | sudo crontab -
# echo ' - Installing cloud-init-vmware-guestinfo ...'
# curl -sSL https://raw.githubusercontent.com/vmware/cloud-init-vmware-guestinfo/master/install.sh | sudo sh - &>/dev/null

## Setup MoTD
echo ' - Setting login banner ...'
BUILDDATE=$(date +"%Y%m")
RELEASE=$(cat /etc/redhat-release)
sudo tee /etc/issue >/dev/null << ISSUE
 __  __ ____  ____  
 |  \/  |  _ \|  _ \ 
 | \  / | |_) | |_) |
 | |\/| |  _ <|  _ < 
 | |  | | |_) | |_) |
 |_|  |_|____/|____/    
 
   $RELEASE ($BUILDDATE)
ISSUE

sudo ln -sf /etc/issue /etc/issue.net

sudo sed -i 's/#Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config

sudo tee /etc/motd >/dev/null << ISSUE
 __  __ ____  ____  
 |  \/  |  _ \|  _ \ 
 | \  / | |_) | |_) |
 | |\/| |  _ <|  _ < 
 | |  | | |_) | |_) |
 |_|  |_|____/|____/    
 
   $RELEASE ($BUILDDATE)
ISSUE

## Unregister from RHSM
echo ' - Unregistering from Red Hat Subscription Manager ...'
sudo subscription-manager unsubscribe --all &>/dev/null
sudo subscription-manager unregister &>/dev/null
sudo subscription-manager clean &>/dev/null

## Final cleanup actions
echo ' - Executing final cleanup tasks ...'
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
    sudo rm -f /etc/udev/rules.d/70-persistent-net.rules
fi
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
sudo cloud-init clean --logs --seed
sudo rm -f /etc/ssh/ssh_host_*
if [ -f /var/log/audit/audit.log ]; then
    echo '' | sudo tee /var/log/audit/audit.log >/dev/null
fi
if [ -f /var/log/wtmp ]; then
    echo '' | sudo tee /var/log/wtmp >/dev/null
fi
if [ -f /var/log/lastlog ]; then
    echo '' | sudo tee /var/log/lastlog >/dev/null
fi

sudo tee /etc/rc.local >/dev/null << ISSUE
#!/bin/bash
# THIS FILE IS ADDED FOR COMPATIBILITY PURPOSES
#
# It is highly advisable to create own systemd services or udev rules
# to run scripts during boot instead of using this file.
#
# In contrast to previous versions due to parallel execution during boot
# this script will NOT be run after all other services.
#
# Please note that you must run 'chmod +x /etc/rc.d/rc.local' to ensure
# that this script will be executed during boot.

touch /var/lock/subsys/local


sudo growpart /dev/sda 3 > /dev/null 2>&1
sudo pvresize /dev/sda3 > /dev/null 2>&1
sudo lvextend -l +100%FREE -r /dev/mapper/sysvg-lvroot > resize.txt
ISSUE

sudo echo ' - Configuration complete'