#!/bin/sh -x
### Hardening Script for CentOS7 Servers.

#Config variables
servicelist=(dhcpd avahi-daemon cups nfslock rpcgssd rpcbind rpcidmapd rpcsvcgssd)
pam_faillock_deny="3"
AUTH_FILES[0]="/etc/pam.d/system-auth"
AUTH_FILES[1]="/etc/pam.d/password-auth"
var_accounts_user_umask="027"
pam_su="/etc/pam.d/su"
faillock_unlock_time="900"
var_accounts_passwords_pam_faillock_fail_interval="900"
var_accounts_tmout="600"
var_accounts_max_concurrent_login_sessions="10"

echo "1.1.1 Disable unused filesystems & 3.5 Uncommon Network Protocols..."
cat > /etc/modprobe.d/hardened.conf << "EOF"
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install vfat /bin/true
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install usb-storage /bin/true
install firewire-core /bin/true
blacklist usb-storage
blacklist firewire-core
EOF

echo "Removing GCC compiler..."
yum -y remove gcc*

echo "Removing legacy services..."
yum -y remove rsh-server rsh ypserv tftp tftp-server talk talk-server telnet-server xinetd

echo "Disabling LDAP..."
yum -y remove openldap-servers
yum -y remove openldap-clients

echo "Disabling DNS..."
yum -y remove bind

echo "Disabling FTP Server..."
yum -y remove vsftpd

echo "Disabling Dovecot..."
yum -y remove dovecot

echo "Disabling Samba..."
yum -y remove samba

echo "Disabling HTTP Proxy Server..."
yum -y remove squid

echo "Disabling SNMP..."
yum -y remove net-snmp

echo "Setting Daemon umask..."
echo "umask 027" >> /etc/init.d/functions

echo "Ensuring unnecessary services are disabled ..."
for i in ${servicelist[@]}; do
  [ $(systemctl disable $i 2> /dev/null) ] || echo "$i is Disabled"
done

echo "Generating a new AIDE database in /var/lib/aide/aide.db.gz..."

/usr/sbin/aide --init && mv -vf /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

echo "Configuring AIDE for Filesystem Integrity Checking..."

echo "05 4 * * * root /usr/sbin/aide --check" >> /etc/crontab

echo "3.4.2-3 - Configuring tcp_wrappers to permit access by internal_cidr..."

echo "ALL: ${IP_RANGE}" > /etc/hosts.allow
echo "ALL: ALL" > /etc/hosts.deny

echo "3.4.4-5 - Setting permissions on hosts.alllow and hosts.deny..."

chown root:root /etc/hosts.allow
chmod 644 /etc/hosts.allow
chown root:root /etc/hosts.deny
chmod 644 /etc/hosts.deny

echo "1.5.1 Ensure core dumps are restricted...."
echo '* hard core 0' > /etc/security/limits.conf

echo "Generating additional logs..."
echo 'auth,user.* /var/log/user' >> /etc/rsyslog.conf
echo 'kern.* /var/log/kern.log' >> /etc/rsyslog.conf
echo 'daemon.* /var/log/daemon.log' >> /etc/rsyslog.conf
echo 'syslog.* /var/log/syslog' >> /etc/rsyslog.conf
echo 'lpr,news,uucp,local0,local1,local2,local3,local4,local5,local6.* /var/log/unused.log' >> /etc/rsyslog.conf
touch /var/log/user /var/log/kern.log /var/log/daemon.log /var/log/syslog /var/log/unused.log
chmod og-rwx /var/log/user /var/log/kern.log /var/log/daemon.log /var/log/syslog /var/log/unused.log
chown root:root /var/log/user /var/log/kern.log /var/log/daemon.log /var/log/syslog /var/log/unused.log

echo "Configuring Audit Log Storage Size..."
sed -i 's/^space_left_action.*$/space_left_action = SYSLOG/' /etc/audit/auditd.conf
sed -i 's/^action_mail_acct.*$/action_mail_acct = root/' /etc/audit/auditd.conf
sed -i 's/^admin_space_left_action.*$/admin_space_left_action = halt/' /etc/audit/auditd.conf

echo "Setting audit rules..."
# Create Secure audit rules
cat <<EOF > /etc/audit/rules.d/audit.rules
# Remove any existing rules
-D
# Increase kernel buffer size
-b 16384
# Failure of auditd causes a kernel panic
-f 2
# Watch syslog configuration
-w /etc/rsyslog.conf
-w /etc/rsyslog.d/
# Watch PAM and authentication configuration
-w /etc/pam.d/
-w /etc/nsswitch.conf
# Watch system log files
-w /var/log/messages
-w /var/log/audit/audit.log
-w /var/log/audit/audit[1-4].log
# Watch audit configuration files
-w /etc/audit/auditd.conf -p wa
-w /etc/audit/audit.rules -p wa
# Watch login configuration
-w /etc/login.defs
-w /etc/securetty
-w /etc/resolv.conf
# Watch cron and at
-w /etc/at.allow
-w /etc/at.deny
-w /var/spool/at/
-w /etc/crontab
-w /etc/anacrontab
-w /etc/cron.allow
-w /etc/cron.deny
-w /etc/cron.d/
-w /etc/cron.hourly/
-w /etc/cron.weekly/
-w /etc/cron.monthly/
# Watch shell configuration
-w /etc/profile.d/
-w /etc/profile
-w /etc/shells
-w /etc/bashrc
-w /etc/csh.cshrc
-w /etc/csh.login
# Watch kernel configuration
-w /etc/sysctl.conf
-w /etc/modprobe.conf
# Watch linked libraries
-w /etc/ld.so.conf -p wa
-w /etc/ld.so.conf.d/ -p wa
# Watch init configuration
-w /etc/rc.d/init.d/
-w /etc/sysconfig/
-w /etc/inittab -p wa
-w /etc/rc.local
-w /usr/lib/systemd/
-w /etc/systemd/
# Watch filesystem and NFS exports
-w /etc/fstab
-w /etc/exports
# Watch xinetd configuration
-w /etc/xinetd.conf
-w /etc/xinetd.d/
# Watch Grub2 configuration
-w /etc/grub2.cfg
-w /etc/grub.d/
# Watch TCP_WRAPPERS configuration
-w /etc/hosts.allow
-w /etc/hosts.deny
# Watch sshd configuration
-w /etc/ssh/sshd_config
# Audit system events
-a always,exit -F arch=b32 -S acct -S reboot -S sched_setparam -S sched_setscheduler -S setrlimit -S swapon
-a always,exit -F arch=b64 -S acct -S reboot -S sched_setparam -S sched_setscheduler -S setrlimit -S swapon
# Audit any link creation
-a always,exit -F arch=b32 -S link -S symlink
-a always,exit -F arch=b64 -S link -S symlink
##################################################
## CIS CentOS Linux 7 Benchmark v2.2.0 auditing ##
##################################################
#4.1.4 Ensure events that modify date and time information are collected
-a always,exit -F arch=b32 -S clock_settime -F a0=0x0 -F key=time-change
-a always,exit -F arch=b64 -S clock_settime -F a0=0x0 -F key=time-change
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S adjtimex,settimeofday -F key=audit_time_rules
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change
#4.1.5 Ensure events that modify user/group information are collected
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
#4.1.6 Ensure events that modify the system's network environment are collected
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale
-w /etc/sysconfig/network-scripts/ -p wa -k system-locale
#4.1.7 Ensure events that modify the system's Mandatory Access Controls are collected
-w /etc/selinux/ -p wa -k MAC-policy
-w /usr/share/selinux/ -p wa -k MAC-policy
#4.1.8 Ensure login and logout events are collected
-w /var/log/tallylog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins
-w /var/log/lastlog -p wa -k logins
#4.1.9 Ensure session initiation information is collected
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins
#4.1.10 Ensure discretionary access control permission modification events are collected
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
#4.1.11 Ensure unsuccessful unauthorized file access attempts are collected
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -k access
-a always,exit -F arch=b32 -S creat,open,openat,open_by_handle_at,truncate,ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S creat,open,openat,open_by_handle_at,truncate,ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S creat,open,openat,open_by_handle_at,truncate,ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S creat,open,openat,open_by_handle_at,truncate,ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
#4.1.13 Ensure successful file system mounts are collected
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
#4.1.14 Ensure file deletion events by users are collected
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S rmdir -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b64 -S rmdir -F auid>=1000 -F auid!=4294967295 -F key=delete
#4.1.15 Ensure changes to system administration scope sudoers is collected
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope
#4.1.16 Ensure system administrator actions are collected
-w /var/log/sudo.log -p wa -k actions
#4.1.17 Ensure kernel module loading and unloading is collected
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b32 -S init_module -S delete_module -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
#4.1.18 Ensure the audit configuration is immutable
-e 2
EOF

echo "4.1.12 Ensure use of privileged commands is collected in auditing..."
for i in $(find / -xdev -type f -perm -4000 -o -type f -perm -2000 2>/dev/null);do echo "-a always,exit -F path=${i} -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged";done >> /etc/audit/rules.d/audit.rules

echo "5.1.2-8 Set Cron and Anacron permissions..."

chown root:root /etc/anacrontab
chmod og-rwx /etc/anacrontab
chown root:root /etc/crontab
chmod og-rwx /etc/crontab
chown root:root /etc/cron.hourly
chmod og-rwx /etc/cron.hourly
chown root:root /etc/cron.daily
chmod og-rwx /etc/cron.daily
chown root:root /etc/cron.weekly
chmod og-rwx /etc/cron.weekly
chown root:root /etc/cron.monthly
chmod og-rwx /etc/cron.monthly
chown root:root /etc/cron.d
chmod og-rwx /etc/cron.d
/bin/rm -f /etc/cron.deny

echo "Creating Banner..."

cat > /etc/issue.net << 'EOF'
/------------------------------------------------------------------------------\
|                       *** INSERT BANNER HERE ***                             |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
\------------------------------------------------------------------------------/
EOF

rm -fr /etc/issue
ln /etc/issue.net /etc/issue

echo "Configuring SSH..."
cat > /etc/ssh/sshd_config << EOF
Port 22
ListenAddress 0.0.0.0
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
UsePrivilegeSeparation yes
KeyRegenerationInterval 3600
ServerKeyBits 2048
SyslogFacility AUTH
LogLevel INFO
ClientAliveInterval 300
ClientAliveCountMax 0
LoginGraceTime 60
PermitRootLogin no
StrictModes yes
MaxAuthTries 4
MaxSessions 10
RSAAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
AuthorizedKeysCommandUser nobody
IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PasswordAuthentication no
KerberosAuthentication no
GSSAPIAuthentication yes
GSSAPICleanupCredentials yes
X11Forwarding no
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
Banner /etc/issue.net
AcceptEnv LANG LC_* XMODIFIERS
Subsystem sftp    /usr/libexec/openssh/sftp-server
UsePAM yes
UseDNS no
DenyUsers no-ssh-access
AllowGroups ${SSH_ALLOW}
Ciphers aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com
PermitUserEnvironment no
EOF

chown root:root /etc/ssh/sshd_config
chmod 600 /etc/ssh/sshd_config

echo "Setting default umask for users..."

grep -q umask /etc/bashrc && \
  sed -i "s/umask.*/umask $var_accounts_user_umask/g" /etc/bashrc
if ! [ $? -eq 0 ]; then
    echo "umask $var_accounts_user_umask" >> /etc/bashrc
fi

grep -q umask /etc/profile && \
  sed -i "s/umask.*/umask $var_accounts_user_umask/g" /etc/profile
if ! [ $? -eq 0 ]; then
    echo "umask $var_accounts_user_umask" >> /etc/profile
fi

echo "Setting account Expiration Parameters....."

sed -i 's/^PASS_MAX_DAYS.*$/PASS_MAX_DAYS  15/' /etc/login.defs
sed -i 's/^PASS_MIN_LEN.*$/PASS_MIN_LEN  14/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*$/PASS_MIN_DAYS  7/' /etc/login.defs
echo "FAIL_DELAY 4" >> /etc/login.defs

echo "5.3.1 - Ensure password creation requirements are configured...."

sed -i 's/^# dcredit.*$/dcredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# minlen.*$/minlen = 14/' /etc/security/pwquality.conf
sed -i 's/^# ucredit.*$/ucredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# lcredit.*$/lcredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# ocredit.*$/ocredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# maxrepeat.*$/maxrepeat = 2/' /etc/security/pwquality.conf
sed -i 's/^# maxclassrepeat.*$/maxclassrepeat = 4/' /etc/security/pwquality.conf
sed -i 's/^# difok.*$/difok = 9/' /etc/security/pwquality.conf
sed -i 's/^# minclass.*$/minclass = 4/' /etc/security/pwquality.conf


echo "Preventing Login to Accounts With Empty Passwords..."

sed --follow-symlinks -i 's/\<nullok\>//g' /etc/pam.d/system-auth
sed --follow-symlinks -i 's/\<nullok\>//g' /etc/pam.d/password-auth

echo "5.3.3 - Limiting Password Reuse...."

if grep -q "remember=" /etc/pam.d/system-auth; then
	sed -i --follow-symlinks "s/\(^password.*sufficient.*pam_unix.so.*\)\(\(remember *= *\)[^ $]*\)/\1remember=5/" /etc/pam.d/system-auth
else
	sed -i --follow-symlinks "/^password[[:space:]]\+sufficient[[:space:]]\+pam_unix.so/ s/$/ remember=5/" /etc/pam.d/system-auth
fi

echo "Setting Deny For Failed Password Attempts..."

for pamFile in "${AUTH_FILES[@]}"
do
	# check presence of pam_faillock.so
	if grep -q "^auth.*pam_faillock.so.*" $pamFile; then

		# pam_faillock.so present, deny directive present?
		if grep -q "^auth.*[default=die].*pam_faillock.so.*authfail.*deny=" $pamFile; then

			# both pam_faillock.so & deny present, just correct deny directive value
			sed -i --follow-symlinks "s/\(^auth.*required.*pam_faillock.so.*preauth.*silent.*\)\(deny *= *\).*/\1\2$pam_faillock_deny/" $pamFile
			sed -i --follow-symlinks "s/\(^auth.*[default=die].*pam_faillock.so.*authfail.*\)\(deny *= *\).*/\1\2$pam_faillock_deny/" $pamFile

		# pam_faillock.so present, but deny directive not yet
		else

			# append correct deny value to appropriate places
			sed -i --follow-symlinks "/^auth.*required.*pam_faillock.so.*preauth.*silent.*/ s/$/ deny=$pam_faillock_deny/" $pamFile
			sed -i --follow-symlinks "/^auth.*[default=die].*pam_faillock.so.*authfail.*/ s/$/ deny=$pam_faillock_deny/" $pamFile
		fi

	# pam_faillock.so not present yet
	else

		# insert pam_faillock.so preauth row with proper value of the 'deny' option before pam_unix.so
		sed -i --follow-symlinks "/^auth.*pam_unix.so.*/i auth        required      pam_faillock.so preauth silent deny=$pam_faillock_deny" $pamFile
		# insert pam_faillock.so authfail row with proper value of the 'deny' option before pam_deny.so, after all modules which determine authentication outcome.
		sed -i --follow-symlinks "/^auth.*pam_deny.so.*/i auth        [default=die] pam_faillock.so authfail deny=$pam_faillock_deny" $pamFile
	fi

	# add pam_faillock.so into account phase
	if ! grep -q "^account.*required.*pam_faillock.so" $pamFile; then
		sed -i --follow-symlinks "/^account.*required.*pam_unix.so/i account     required      pam_faillock.so" $pamFile
	fi
done

echo "Setting Lockout Time For Failed Password Attempts..."

for pamFile in "${AUTH_FILES[@]}"
do

	# pam_faillock.so already present?
	if grep -q "^auth.*pam_faillock.so.*" $pamFile; then

		# pam_faillock.so present, unlock_time directive present?
		if grep -q "^auth.*[default=die].*pam_faillock.so.*authfail.*unlock_time=" $pamFile; then

			# both pam_faillock.so & unlock_time present, just correct unlock_time directive value
			sed -i --follow-symlinks "s/\(^auth.*required.*pam_faillock.so.*preauth.*silent.*\)\(unlock_time *= *\).*/\1\2$faillock_unlock_time/" $pamFile
			sed -i --follow-symlinks "s/\(^auth.*[default=die].*pam_faillock.so.*authfail.*\)\(unlock_time *= *\).*/\1\2$faillock_unlock_time/" $pamFile

		# pam_faillock.so present, but unlock_time directive not yet
		else

			# append correct unlock_time value to appropriate places
			sed -i --follow-symlinks "/^auth.*required.*pam_faillock.so.*preauth.*silent.*/ s/$/ unlock_time=$faillock_unlock_time/" $pamFile
			sed -i --follow-symlinks "/^auth.*[default=die].*pam_faillock.so.*authfail.*/ s/$/ unlock_time=$faillock_unlock_time/" $pamFile
		fi

	# pam_faillock.so not present yet
	else

		# insert pam_faillock.so preauth & authfail rows with proper value of the 'unlock_time' option
		sed -i --follow-symlinks "/^auth.*sufficient.*pam_unix.so.*/i auth        required      pam_faillock.so preauth silent unlock_time=$faillock_unlock_time" $pamFile
		sed -i --follow-symlinks "/^auth.*sufficient.*pam_unix.so.*/a auth        [default=die] pam_faillock.so authfail unlock_time=$faillock_unlock_time" $pamFile
		sed -i --follow-symlinks "/^account.*required.*pam_unix.so/i account     required      pam_faillock.so" $pamFile
	fi
done

echo "Configuring the root Account for Failed Password Attempts..."

for pamFile in "${AUTH_FILES[@]}"
do
	# pam_faillock.so already present?
	if grep -q "^auth.*pam_faillock.so.*" $pamFile; then

		# pam_faillock.so present, preauth even_deny_root directive present?
		if ! grep -q "^auth.*required.*pam_faillock.so.*preauth.*even_deny_root" $pamFile; then
			# even_deny_root is not present
			sed -i --follow-symlinks "s/\(^auth.*required.*pam_faillock.so.*preauth.*\).*/\1 even_deny_root/" $pamFile
		fi

		# pam_faillock.so present, authfail even_deny_root directive present?
		if ! grep -q "^auth.*\[default=die\].*pam_faillock.so.*authfail.*even_deny_root" $pamFile; then
			# even_deny_root is not present
			sed -i --follow-symlinks "s/\(^auth.*\[default=die\].*pam_faillock.so.*authfail.*\).*/\1 even_deny_root/" $pamFile
		fi

	# pam_faillock.so not present yet
	else

		# insert pam_faillock.so preauth row with proper value of the 'deny' option before pam_unix.so
		sed -i --follow-symlinks "/^auth.*pam_unix.so.*/i auth        required      pam_faillock.so preauth silent even_deny_root" $pamFile
		# insert pam_faillock.so authfail row with proper value of the 'deny' option before pam_deny.so, after all modules which determine authentication outcome.
		sed -i --follow-symlinks "/^auth.*pam_deny.so.*/i auth        [default=die] pam_faillock.so authfail silent even_deny_root" $pamFile
	fi

done

echo "Setting Interval For Counting Failed Password Attempts..."

for pamFile in "${AUTH_FILES[@]}"
do

	# pam_faillock.so already present?
	if grep -q "^auth.*pam_faillock.so.*" $pamFile; then

		# pam_faillock.so present, 'fail_interval' directive present?
		if grep -q "^auth.*[default=die].*pam_faillock.so.*authfail.*fail_interval=" $pamFile; then

			# both pam_faillock.so & 'fail_interval' present, just correct 'fail_interval' directive value
			sed -i --follow-symlinks "s/\(^auth.*required.*pam_faillock.so.*preauth.*silent.*\)\(fail_interval *= *\).*/\1\2$var_accounts_passwords_pam_faillock_fail_interval/" $pamFile
			sed -i --follow-symlinks "s/\(^auth.*[default=die].*pam_faillock.so.*authfail.*\)\(fail_interval *= *\).*/\1\2$var_accounts_passwords_pam_faillock_fail_interval/" $pamFile

		# pam_faillock.so present, but 'fail_interval' directive not yet
		else

			# append correct 'fail_interval' value to appropriate places
			sed -i --follow-symlinks "/^auth.*required.*pam_faillock.so.*preauth.*silent.*/ s/$/ fail_interval=$var_accounts_passwords_pam_faillock_fail_interval/" $pamFile
			sed -i --follow-symlinks "/^auth.*[default=die].*pam_faillock.so.*authfail.*/ s/$/ fail_interval=$var_accounts_passwords_pam_faillock_fail_interval/" $pamFile
		fi

	# pam_faillock.so not present yet
	else

		# insert pam_faillock.so preauth & authfail rows with proper value of the 'fail_interval' option
		sed -i --follow-symlinks "/^auth.*sufficient.*pam_unix.so.*/i auth        required      pam_faillock.so preauth silent fail_interval=$var_accounts_passwords_pam_faillock_fail_interval" $pamFile
		sed -i --follow-symlinks "/^auth.*sufficient.*pam_unix.so.*/a auth        [default=die] pam_faillock.so authfail fail_interval=$var_accounts_passwords_pam_faillock_fail_interval" $pamFile
		sed -i --follow-symlinks "/^account.*required.*pam_unix.so/i account     required      pam_faillock.so" $pamFile
	fi
done

echo "Set Interactive Session Timeout...."

if grep --silent ^TMOUT /etc/profile ; then
        sed -i "s/^TMOUT.*/TMOUT=$var_accounts_tmout/g" /etc/profile
else
        echo -e "\n# Set TMOUT to $var_accounts_tmout per security requirements" >> /etc/profile
        echo "TMOUT=$var_accounts_tmout" >> /etc/profile
fi

echo "Limiting the Number of Concurrent Login Sessions Allowed Per User...."

if grep -q '^[^#]*\<maxlogins\>' /etc/security/limits.d/*.conf; then
	sed -i "/^[^#]*\<maxlogins\>/ s/maxlogins.*/maxlogins $var_accounts_max_concurrent_login_sessions/" /etc/security/limits.d/*.conf
elif grep -q '^[^#]*\<maxlogins\>' /etc/security/limits.conf; then
	sed -i "/^[^#]*\<maxlogins\>/ s/maxlogins.*/maxlogins $var_accounts_max_concurrent_login_sessions/" /etc/security/limits.conf
else
	echo "*	hard	maxlogins	$var_accounts_max_concurrent_login_sessions" >> /etc/security/limits.conf
fi

echo "Restricting Access to the su Command..."

line_num="$(grep -n "^\#auth[[:space:]]*required[[:space:]]*pam_wheel.so[[:space:]]*use_uid" ${pam_su} | cut -d: -f1)"
sed -i "${line_num} a auth		required	pam_wheel.so use_uid" ${pam_su}


echo "Locking inactive user accounts..."
useradd -D -f 30

echo "6.1 System File Permissions..."
chmod 644 /etc/passwd
chmod 600 /etc/passwd-
chmod 000 /etc/shadow
chmod 000 /etc/gshadow
chmod 000 /etc/gshadow-
chmod 644 /etc/group
chmod 600 /etc/group-

chown root:root /etc/passwd
chown root:root /etc/passwd-
chown root:root /etc/shadow
chown root:root /etc/gshadow
chown root:root /etc/gshadow-
chown root:root /etc/group
chown root:root /etc/group-


echo "Ensure Logrotate Runs Periodically..."
sed -i "s/weekly/daily/g" /etc/logrotate.conf
sed -i "s/monthly/weekly/g" /etc/logrotate.conf
sed -i "s/rotate 4/rotate 3/g" /etc/logrotate.conf

echo "Disallow direct root logins.."

sudo echo > /etc/securetty

echo "Configuring sysctl configuration..."
cat > /etc/sysctl.conf  << EOF
net.ipv4.ip_forward = ${IPV4FORWARD}
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.route.flush = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
#1.5.1 Ensure core dumps are restricted
fs.suid_dumpable = 0
#Ensure address space layout randomization (ASLR) is enabled
kernel.randomize_va_space = 2
#Recommendations from Lynis
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.sysrq = 0
kernel.yama.ptrace_scope = 1
EOF

echo "Ensuring YUM removes previous version...."

if grep --silent ^clean_requirements_on_remove /etc/yum.conf ; then
        sed -i "s/^clean_requirements_on_remove.*/clean_requirements_on_remove=1/g" /etc/yum.conf
else
        echo -e "\n# Set clean_requirements_on_remove to 1 per security requirements" >> /etc/yum.conf
        echo "clean_requirements_on_remove=1" >> /etc/yum.conf
fi

echo "Ensuring gpgcheck Enabled for Local Packages...."

if grep --silent ^localpkg_gpgcheck /etc/yum.conf ; then
        sed -i "s/^localpkg_gpgcheck.*/localpkg_gpgcheck=1/g" /etc/yum.conf
else
        echo -e "\n# Set localpkg_gpgcheck to 1 per security requirements" >> /etc/yum.conf
        echo "localpkg_gpgcheck=1" >> /etc/yum.conf
fi


echo "Performing a Yum update"
yum update -y

echo "Performing a Yum clean"
yum clean all

echo " Setting grub2 permissions"
chmod 600 /boot/grub2/grub.cfg

echo "Enabling auditing for processes which start prior to the Audit Daemon..."
# Correct the form of default kernel command line in /etc/default/grub
grep -q ^GRUB_CMDLINE_LINUX=\".*audit=0.*\" /etc/default/grub && \
  sed -i "s/audit=[^[:space:]\+]/audit=1/g" /etc/default/grub
if ! [ $? -eq 0 ]; then
  sed -i "s/\(GRUB_CMDLINE_LINUX=\)\"\(.*\)\"/\1\"\2 audit=1\"/" /etc/default/grub
fi

# Correct the form of kernel command line for each installed kernel
# in the bootloader
/sbin/grubby --update-kernel=ALL --args="audit=1"

echo ""
echo "Successfully Completed Hardening"
