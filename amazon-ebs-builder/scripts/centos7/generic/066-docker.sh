#!/bin/sh -x

# Get the latest cadvisor version from GIT

version_ca=$(curl -s https://api.github.com/repos/google/cadvisor/releases/latest|grep tag_name|awk -F\" '{print $4}'|tr -d '^v')

# Install Docker dependencies
yum install -y yum-utils device-mapper-persistent-data lvm2

# Add docker-ce repos and enable

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

yum-config-manager --enable docker-ce-edge

yum-config-manager --enable docker-ce-test

## 1.1 Ensure a separate partition for containers has been created
echo "Creating seperate partition for Docker..."

echo "/dev/mapper/vg01-varlibd /var/lib/docker        xfs     defaults        0 0" >> /etc/fstab

mkdir /var/lib/docker

mount -a

# Install Docker
yum install -y --setopt=obsoletes=0 \
        docker-ce-${DOCKER_VERSION}

# Download cadvisor & node_exporter

curl -sL https://github.com/google/cadvisor/releases/download/v${version_ca}/cadvisor -o /usr/sbin/cadvisor

chmod 755 /usr/sbin/node_exporter /usr/sbin/cadvisor

chown root:root /usr/sbin/node_exporter /usr/sbin/cadvisor

# Create directories for ECS agent
mkdir -p /var/log/ecs /var/lib/ecs/data /etc/ecs

# Write ECS config file
cat << EOF > /etc/ecs/ecs.config
ECS_DATADIR=/data
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
ECS_LOGFILE=/log/ecs-agent.log
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs"]
ECS_LOGLEVEL=info
ECS_CLUSTER=default
EOF

# Write systemd unit file
cat << EOF > /etc/systemd/system/docker-container@ecs-agent.service
[Unit]
Description=Docker Container %I
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker rm -f %i
ExecStart=/usr/bin/docker run --name %i \
--privileged \
--restart=on-failure:10 \
--volume=/var/run:/var/run \
--volume=/var/log/ecs/:/log:Z \
--volume=/var/lib/ecs/data:/data:Z \
--volume=/etc/ecs:/etc/ecs \
--net=host \
--env-file=/etc/ecs/ecs.config \
amazon/amazon-ecs-agent:latest
ExecStop=/usr/bin/docker stop %i

[Install]
WantedBy=default.target
EOF

systemctl daemon-reload
systemctl enable docker-container@ecs-agent.service

# Write systemd unit file for cadvisor
cat << EOF > /etc/systemd/system/cadvisor.service
[Unit]
Description=cadvisor

[Service]
ExecStart=/usr/sbin/cadvisor

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cadvisor.service
systemctl enable docker
systemctl start docker

cat << EOF > /etc/systemd/system/burbank-network.service
[Unit]
Description=Create the Burbank Docker service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/docker network create --driver bridge --gateway ${DOCKER_NETWORK}.1 --subnet ${DOCKER_NETWORK}.0/16 ${OWNER}
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable burbank-network.service
