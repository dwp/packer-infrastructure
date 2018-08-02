#!/bin/sh -x
#

# locale
echo 'en_GB.UTF-8 UTF-8' > /etc/locale.gen
echo 'LANG=en_GB.UTF-8' > /etc/locale.conf

# Create basic homedir for root user
cp -a /etc/skel/.bash* /root

# Timezone
cp /usr/share/zoneinfo/UTC /etc/localtime
echo 'ZONE="UTC"' > /etc/sysconfig/clock


# Configure chrony
cat > /etc/chrony.conf << EOT
# Use AWS NTP
server ${NTP_SOURCE} prefer iburst

# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Specify directory for log files.
logdir /var/log/chrony

# Select which information is logged.
#log measurements statistics tracking
EOT

# Configure chronyd options
cat > /etc/sysconfig/chronyd << EOT
OPTIONS="-u chrony"
EOT

# Remove requiretty setting in sudoers if it exists
sed -i -r "s@^.*requiretty@#Defaults !requiretty@" /etc/sudoers

# Disable firstboot
echo "RUN_FIRSTBOOT=NO" > /etc/sysconfig/firstboot

# instance type markers - Pulled from CentOS AMI creation kickstart
echo 'genclo' > /etc/yum/vars/infra

# setup systemd to boot to the right runlevel
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target

# Disable AutoVT services for TTYs
sed -i -r 's@^#NAutoVTs=.*@NAutoVTs=0@' /etc/systemd/logind.conf

# 1.1.15-17
echo "tmpfs /dev/shm tmpfs defaults,nodev,nosuid,noexec 0 0" >> /etc/fstab
