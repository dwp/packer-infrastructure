#!/bin/sh
set -x
set -e

# Set a message of the day.
echo -e "\n\nHardened App container image built for ${APP_NAME} application on $(date)." > /etc/motd

# Remove any existing crontabs.
rm -fr /var/spool/cron
rm -fr /etc/crontabs
rm -fr /etc/periodic

# Remove all but a handful of admin commands (su-exec for Hashicorp, not installed by default) in /sbin & /usr/sbin
find /sbin /usr/sbin ! -type d \
  -a ! -name nologin \
  -a ! -name ip \
  -a ! -name nginx \
  -a ! -name su-exec \
  -delete

# Remove world-writable permissions.
#NOTE: This breaks apps that need to write to /tmp
find / -xdev -type d -perm +0002 -exec chmod o-w {} +
find / -xdev -type f -perm +0002 -exec chmod o-w {} +

# Remove unnecessary user accounts apart from ${USER} and root
sed -i -r '/^('"${USER}"'|root)/!d' /etc/group
sed -i -r '/^('"${USER}"'|root)/!d' /etc/passwd

# Remove interactive login shell for root
sed -i -r '/^'"${USER}"':/! s#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd

sysdirs="
  /bin
  /etc
  /lib
  /sbin
  /usr
"

# Remove apk configs.
find $sysdirs -xdev -regex '.*apk.*' -exec rm -fr {} +

# Remove crufty...
#   /etc/shadow-
#   /etc/passwd-
#   /etc/group-
find $sysdirs -xdev -type f -regex '.*-$' -exec rm -f {} +

# Ensure system dirs are owned by root and not writable by anybody else.
find $sysdirs -xdev -type d \
  -exec chown root:root {} \; \
  -exec chmod 0755 {} \;

# Remove all suid files.
find $sysdirs -xdev -type f -a -perm +4000 -delete

# Remove other programs that could be dangerous/unnecessary.
find $sysdirs -xdev \( \
  -name hexdump -o \
  -name chgrp -o \
  -name chmod -o \
  -name chown -o \
  -name ln -o \
  -name od -o \
  -name nslookup -o \
  -name dig -o \
  -name nsupdate -o \
  -name ssl_client -o \
  -name host -o \
  -name strings -o \
  -name su \
  \) -delete

# Remove other programs that could be dangerous/unnecessary in /usr/bin
find /usr/bin -xdev \( \
  -name make -o \
  -name appletviewer -o \
  \) -delete

# Remove any app local configuration files
find /opt/${APP_NAME} \( \
  -name ".env*" -o \
  -name "*.yml" -o \
  \) -delete

# Remove init scripts since we do not use them.
rm -fr /etc/init.d
rm -fr /lib/rc
rm -fr /etc/conf.d
rm -fr /etc/inittab
rm -fr /etc/runlevels
rm -fr /etc/rc.conf

# Remove kernel tunables since we do not need them.
rm -fr /etc/sysctl*
rm -fr /etc/modprobe.d
rm -fr /etc/modules
rm -fr /etc/mdev.conf
rm -fr /etc/acpi

# Remove root homedir since we do not need it.
rm -fr /root

# Remove fstab since we do not need it.
rm -f /etc/fstab

# Remove broken symlinks (because we removed the targets above).
find $sysdirs -xdev -type l -exec test ! -e {} \; -delete
