# Install wget
yum -y install wget

version=${FULL_VERSION}

# Detect primary root drive
if [ -e /dev/xvda ]; then
  drive=xvda
elif [ -e /dev/vda ]; then
  drive=vda
elif [ -e /dev/sda ]; then
  drive=sda
fi

mkdir /boot/centos
cd /boot/centos
wget ${MIRROR_URL}/${FULL_VERSION}/os/x86_64/isolinux/vmlinuz
wget ${MIRROR_URL}/${FULL_VERSION}/os/x86_64/isolinux/initrd.img

# This kickstart file has been created to install the Core Centos7 OS and partition as per CIS CentOS Linux 7 Benchmark (v2.2.0 - 12-27-2017).
cat > /boot/centos/kickstart.ks << EOKSCONFIG
# Installation settings
text
install
firstboot --disable
eula --agreed
unsupported_hardware
skipx
lang en_GB.UTF-8
keyboard uk
auth --enableshadow --passalgo=sha512
timezone UTC --isUtc

# Repo settings
repo --name="base" --baseurl=${MIRROR_URL}${FULL_VERSION}/os/x86_64/
# Including the updates repo ensures we install the latest packages at install time
url --url="${MIRROR_URL}7/os/x86_64/"
repo --name="os" --baseurl=${MIRROR_URL}${FULL_VERSION}/os/x86_64/ --cost=100
repo --name="updates" --baseurl=${MIRROR_URL}${FULL_VERSION}/updates/x86_64/ --cost=100
repo --name="extras" --baseurl=${MIRROR_URL}${FULL_VERSION}/extras/x86_64/ --cost=100

# System settings
rootpw --iscrypted nothing
network --onboot yes --device eth0 --bootproto dhcp --ipv6=auto --activate
firewall --enabled --ssh
selinux --enforcing
services --enabled=sshd

# bootloader configuration
bootloader --location=mbr --append="crashkernel=auto rhgb quiet" --timeout=0

# Initialize (format) all disks
zerombr
clearpart --linux --initlabel

# Create primary system partitions
part /boot --fstype=xfs --size=512 --ondisk=${drive}
part pv.00 --grow --size=1 --ondisk=${drive}

# Create a volume group
volgroup vg00 --pesize=4096 pv.00

# Create LVM partitions as per CIS guide
logvol /  --fstype="xfs"  --size=2048 --name=root --vgname=vg00
logvol /tmp --fstype="xfs" --size=2048 --name=tmp --vgname=vg00 --fsoptions=nodev,noexec,nosuid
logvol /var --fstype="xfs" --size=1024 --name=var --vgname=vg00
logvol /var/tmp --fstype="xfs" --size=1024 --name=vartmp --vgname=vg00 --fsoptions=nodev,noexec,nosuid
logvol /var/log --fstype="xfs" --size=3072 --name=log --vgname=vg00
logvol /var/log/audit --fstype="xfs" --size=3072 --name=audit --vgname=vg00
logvol /home --fstype="xfs" --size=2048 --name=home --vgname=vg00 --fsoptions=nodev
# Application LV
logvol /opt --fstype="xfs" --size=2048 --name=opt --vgname=vg00
logvol /usr --fstype="xfs" --size=4096 --name=usr --vgname=vg00
# Vault client
logvol /vault_client --fstype="xfs" --size=512 --name=vault_client --vgname=vg00

# Base Service configuration
services --enabled=sshd

# Packages selection
%packages --excludedocs
# Core only
@core
# Cloud-init is required at boot-time
cloud-init
%end

# Basic cleanup
%post

# Cleanup SSH keys
rm -f /etc/ssh/*key*
rm -rf ~/.ssh/

# Let SELinux relabel FS on next boot
touch /.autorelabel
%end
reboot --eject
EOKSCONFIG

echo "menuentry 'centosinstall' {
        set root='hd0,msdos1'
    linux /boot/centos/vmlinuz ip=dhcp ksdevice=eth0 ks=hd:${drive}1:/boot/centos/kickstart.ks method=${MIRROR_URL}${FULL_VERSION}/os/x86_64/ lang=en_GB.UTF-8 keymap=uk
        initrd /boot/centos/initrd.img
}" >> /etc/grub.d/40_custom

echo 'GRUB_DEFAULT=saved
GRUB_HIDDEN_TIMEOUT=
GRUB_TIMEOUT=2
GRUB_RECORDFAIL_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet nosplash vga=771 nomodeset"
GRUB_DISABLE_LINUX_UUID=true' > /etc/default/grub

grub2-set-default 'centosinstall'
grub2-mkconfig -o /boot/grub2/grub.cfg

rm -rf ~/.ssh/*
rm -rf /root/*

reboot
