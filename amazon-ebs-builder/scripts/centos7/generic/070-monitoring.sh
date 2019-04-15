#!/bin/sh -x

# Get the latest node_exporter versions from GIT

version_ne=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest|grep tag_name|awk -F\" '{print $4}'|tr -d '^v')

# Download node_exporter

curl -sL https://github.com/prometheus/node_exporter/releases/download/v${version_ne}/node_exporter-${version_ne}.linux-amd64.tar.gz |tar -zxvf - -C /usr/sbin/ --strip-components=1 node_exporter-${version_ne}.linux-amd64/node_exporter

chmod 755 /usr/sbin/node_exporter

chown root:root /usr/sbin/node_exporter

# Write systemd unit file for node_exporter
cat << EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter

[Service]
ExecStart=/usr/sbin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter.service
