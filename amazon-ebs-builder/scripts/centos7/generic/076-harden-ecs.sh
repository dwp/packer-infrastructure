
#!/bin/sh -x

systemctl stop docker

## 2.1 - 2.18 Docker daemon configuration
cat > /etc/docker/daemon.json <<EOF
{
   "icc": false,
   "userns-remap": "$OWNER",
   "log-driver": "awslogs",
   "log-level": "info",
   "disable-legacy-registry": true,
   "live-restore": true,
   "userland-proxy": false,
   "no-new-privileges": true
}
EOF

## 1.6 - 1.13 Add Docker CE Auditing
echo "Adding Audit rules..."

cat <<EOF >> /etc/audit/rules.d/audit.rules
# CIS Docker CE v1.1.0 requirements; 1.6 - 1.13
-w /usr/bin/docker -k docker
-w /var/lib/docker -k docker
-w /etc/docker -k docker
-w /usr/lib/systemd/system/docker.service -k docker
-w /etc/docker/daemon.json -k docker
-w /usr/bin/docker-containerd -k docker
-w /usr/bin/docker-runc -k docker
EOF

#### 2.8 - Enable user namespace support...

echo $OWNER:$GUID:1 > /etc/subuid
echo $OWNER:100000:65536 >> /etc/subuid

echo $OWNER:$GUID:1 > /etc/subgid
echo $OWNER:100000:65536 >> /etc/subgid


grubby --args="namespace.unpriv_enable=1 user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)"

echo "user.max_user_namespaces=15076" >> /etc/sysctl.conf

semodule -i /tmp/user_namespace.pp
