# ----------------------------------------------------------------------------
# Name:         ks.cfg
# Description:  Kickstart File for RHEL7
# Author:       Michael Poore (@mpoore)
# URL:          https://github.com/v12n-io/packer
# Date:         04/03/2022
# ----------------------------------------------------------------------------

# Install Settings
cdrom
text
eula --agreed

# Configurable OS Settings
lang ${vm_os_language}
keyboard ${vm_os_keyboard}
timezone ${vm_os_timezone}

# Network Settings
network --bootproto=dhcp
firewall --enabled --ssh

# Account Settings
rootpw --plaintext ${build_password}
user --name=${build_username} --plaintext --password=${build_password} --groups=wheel

# Security Settings
auth --passalgo=sha512 --useshadow
selinux --enforcing

# Storage Settings
bootloader --location=mbr
zerombr
clearpart --all --initlabel


## Disk NO LVM
part /boot/efi --fstype=vfat --size=500
part /boot --fstype=xfs --size=1000
part swap --fstype=swap --size=8000
part / --fstype=xfs --size=2000 --grow

## Disk LVM
# part /boot --fstype xfs --size=1024
# part /boot/efi --fstype vfat --size=512
# part pv.01 --size=1024 --grow
# volgroup sysvg pv.01
# logvol swap --fstype swap --name=lvswap --vgname=sysvg --size=8192
# logvol / --fstype xfs --name=lvroot --vgname=sysvg --size=16384
# logvol /tmp --fstype xfs --name=lvtmp --vgname=sysvg --size=4096
# Software / Package Settings
skipx
services --enabled=NetworkManager,sshd

%packages --ignoremissing --excludedocs
@core
sudo
open-vm-tools
net-tools
vim
wget
curl
perl
git
yum-utils
unzip
-iwl*firmware
%end

# Post-Install Commands
%post
echo "${build_username} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${build_username}
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
%end

reboot --eject