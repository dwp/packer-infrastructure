#!/bin/sh -x

#Remove temp files
rm -f /tmp/env_vars

# Clean YUM
yum history new
yum -y clean all
truncate -c -s 0 /var/log/yum.log

# Lock the root user
passwd -d root
passwd -l root

# Shred SSH key files
shred -uf /etc/ssh/*_key
shred -uf /etc/ssh/*_key.pub

# Shred history files
find /root /home -name '.bash_history' -exec shred -uf {} \;

# Remove random-seed so its not the same across images
rm -f /var/lib/random-seed

# Remove ssh keys from user home dirs
find /root /home -name 'authorized_keys' -exec truncate -s 0 {} \;

# Shrink / rm logs
logrotate -f /etc/logrotate.conf
rm -f /var/log/*-???????? /var/log/*.gz
rm -f /var/log/dmesg.old
rm -rf /var/log/anaconda
cat /dev/null > /var/log/audit/audit.log
cat /dev/null > /var/log/wtmp
cat /dev/null > /var/log/lastlog
cat /dev/null > /var/log/grubby
rm -fr /tmp/*
rm -rf /var/lib/cloud/*

# Fix SELinux contexts (bootstrapping in chroot requires a full relabel)
/sbin/setfiles -F -e /proc -e /sys -e /dev /etc/selinux/targeted/contexts/files/file_contexts /

# Remove policy-rc.d to allow services to restart on boot
rm -f /usr/sbin/policy-rc.d

# Disk clean up
dd if=/dev/zero of=/zeros bs=1M
rm -f /zeros
sync
