#!/bin/sh -x
# Sets the cloud-init config

cat > /etc/cloud/cloud.cfg << EOF
users:
 - default

disable_root: true
ssh_pwauth: false

mount_default_fields: [~, ~, 'auto', 'defaults,nofail', '0', '2']
resize_rootfs: true
resize_rootfs_tmp: /dev
ssh_deletekeys: true
ssh_genkeytypes:  ~
syslog_fix_perms: ~

cloud_init_modules:
 - migrator
 - bootcmd
 - write-files
 - growpart
 - resizefs
 - set_hostname
 - update_hostname
 - update_etc_hosts
 - rsyslog
 - users-groups
 - ssh

cloud_config_modules:
 - mounts
 - locale
 - set-passwords
 - yum-add-repo
 - package-update-upgrade-install
 - timezone
 - mcollective
 - disable-ec2-metadata
 - runcmd

cloud_final_modules:
 - rightscale_userdata
 - scripts-per-once
 - scripts-per-boot
 - scripts-per-instance
 - scripts-user
 - ssh-authkey-fingerprints
 - keys-to-console
 - phone-home
 - final-message

system_info:
  default_user:
    name: centos
    lock_passwd: true
    gecos: Cloud User
    groups: [wheel, adm, systemd-journal]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
  distro: rhel
  paths:
    cloud_dir: /var/lib/cloud
    templates_dir: /etc/cloud/templates
  ssh_svcname: sshd

datasource_list: [ Ec2, None ]
preserve_hostname: true
# vim:syntax=yaml
EOF

chown root:root /etc/cloud/cloud.cfg
chmod 664 /etc/cloud/cloud.cfg
