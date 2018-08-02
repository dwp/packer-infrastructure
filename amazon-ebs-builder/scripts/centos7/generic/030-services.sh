#!/bin/sh -x
#
# Enable necessary services
systemctl -q enable rsyslog
systemctl -q enable sshd
systemctl -q enable auditd
systemctl -q enable chronyd
systemctl -q enable rsyslog
systemctl -q enable network
systemctl -q enable crond

# Disable kdump
systemctl -q disable kdump

# 1.1.2
systemctl unmask tmp.mount
systemctl enable tmp.mount

sed -i 's/^Options=.*$/Options=mode=1777,strictatime,noexec,nodev,nosuid/' /etc/systemd/system/local-fs.target.wants/tmp.mount


# AWS Specific
systemctl -q enable cloud-init
systemctl -q enable cloud-config
systemctl -q enable cloud-final
systemctl -q enable cloud-init-local
