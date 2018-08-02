#!/bin/sh -x
#

# Install basic set of packages
yum -y install \
	aide \
	chrony \
	cloud-init \
	cloud-utils-growpart \
	cronie-anacron \
	dracut-config-generic \
	epel-release \
	grub2 \
	iptables-services \
	kernel \
	tcp_wrappers

# Strip down CentOS
yum -y remove \
	*-firmware \
	authconfig \
	avahi \
	biosdevname \
	btrfs-progs \
	ethtool \
	pciutils-libs \
	kernel-tools \
	firewalld* \
	hwdata \
	iprutils \
	irqbalance \
	kbd \
	kexec-tools \
	linux-firmware \
	man-db \
	man-pages \
	mariadb* \
	microcode_ctl \
	NetworkManager* \
	plymouth* \
	postfix \
	sg3_utils* \
	yum-utils \
	--setopt="clean_requirements_on_remove=1"

# Install JQ, pip and boto3
yum -y install python-pip jq
# Install latest python from pypi using pip
pip install --upgrade \
	pip \
	boto3 \
	awscli

	chmod 755 /bin/aws*
