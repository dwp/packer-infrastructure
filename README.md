# Burbank Secure Image Builder

## Overview

This repository contains templates for building both hardened Alpine container images and Centos AMIs.
We have used the [Packer machine image build tool](http://www.packer.io/) to create these.

## Alpine images

Under construction.

## AMIs

The [Amazon EBS Builder](https://www.packer.io/docs/builders/amazon-ebs.html) has been used to create our EC2 & ECS AMIs, which are compliant to the CIS CentOS Linux 7 Benchmark (v2.2.0 - 12-27-2017).
Auditing tools OpenSCAP (C2S profile) and Lynis have been used to test the Burbank builds.

We have not applied the following CIS Recommendations:
- Set a Boot Loader password [1.4.2] - AWS instances do not allow access to the bootloader or console when the instance is started.
- Configured rsyslog to send logs to a remote host [4.2.1.4] - This is handled by Cloudwatch. Our long-term strategy is to have nothing writing to the disk/OS to allow a move to completely immutable infrastructure.


[EBS Builder](amazon-ebs-builder/) contains four JSONs files CentOS7-base/ec2/ecs/infra.json

[base](amazon-ebs-builder/CentOS7-base.json) - this template takes the latest CentOS Linux 7 x86_64 HVM EBS image from the AWS Marketplace, increases the disk size from 8GB to your chosen size, runs a yum update and adds it to your private AMIs within your AWS Account - this should only be required to happen once. We know we are always building against a 'known good' image, which is within a private repository.

[ec2](amazon-ebs-builder/CentOS7-ec2.json) - this template takes the base AMI mentioned above, creates a kickstart file and runs a series of scripts to build an EC2 ready AMI. The build is completely stripped down (243 [packages](amazon-ebs-builder/info/ec2_package_list.txt) and has the necessary software to run the Core CentOS.

[ecs](amazon-ebs-builder/CentOS7-ecs.json) - - this template takes the base AMI mentioned above, creates a kickstart file and runs a series of scripts to build an EC2 ready AMI. The build is completely stripped down (243 [packages](amazon-ebs-builder/info/ecs_package_list.txt) and has the necessary software to run a Core CentOS and ECS containers.

[infra](amazon-ebs-builder/CentOS7-infra.json) -  this template takes the base AMI mentioned above, creates a kickstart file and runs a series of scripts to build an EC2 ready AMI. The build is completely stripped down (roughly 240 packages) and has the necessary software to run the Core CentOS with relaxed firewall rules for services such as Jenkins which require some outbound internet access - this should be used in Development environments only.

# ec2, ecs and infra scripts

[generic scripts](amazon-ebs-builder/scripts/centos7/generic) - These scripts run on every build.

* 000-bash.sh - pushes out a kickstart file, reboots the server and lays down the CoreOS. This includes the following LVM partitioning:

| Mount Point   | Size          |  
| ------------- | ------------- |
| /             | 2GB           |
| /tmp          | 2GB           |
| /var          | 1GB           |
| /var/tmp      | 1GB           |
| /var/log      | 3GB           |
| /var/log/audit| 3GB           |
| /home         | 2GB           |
| /opt          | 4GB           |


* 010-packages.sh - strips down the OS, installs any of our required packages.
* 020-config.sh - sets up the base configuration.
* 030-services.sh - disables/enables services.
* 040-network.sh - disables ipv6 and sets a generic ipv4 configuration.
* 050-cloud-init.sh - sets the cloud-init configuration.
* 060-grub.sh - configures grub and ensures the build can be use on all instance types.
* 090-harden.sh - hardens the build. [Please insert your banner - line 288]
* 010-cleanup.sh - cleans the build.


[ec2 scripts](amazon-ebs-builder/scripts/centos7/ec2) - In addition to generic_scripts, the below scripts will run on ec2 AMI builds.
* 095-iptables.sh - configures the required iptable rules for an EC2 node. The ruleset is restricted to the below and everything else is dropped and logging is enabled;

The ruleset allows:
1. Local DHCP.
2. DNS lookup within the ip range set in variable internal_cidr.
3. New and established incoming connections to ports defined in variable app_ports within the internal_cidr.
4. SSH access from the internal_cidr.
5. HTTPS access within AWS infrastructure, which defined in aws_networks variable.
6. NTP access, to the source defined in ntp_source variable.
7. HTTP access to AWS Instance Metadata and User Data endpoint for EC2.


[ecs scripts](amazon-ebs-builder/scripts/centos7/ecs) - In addition to generic_scripts, the below scripts will run on ecs AMI builds.
* 066-docker.sh - Installs the version of docker specified in the JSON.
* 096-iptables.sh - configures the required iptable rules for an ECS node. The ruleset is restricted to the below and everything else is dropped and logging is enabled;

The ruleset allows:
1. Local DHCP.
2. DNS lookup within the ip range set in variable internal_cidr.
3. New and established incoming connections to ports defined in variable app_ports within the internal_cidr.
4. SSH access from the internal_cidr.
5. HTTPS access within AWS infrastructure, which defined in aws_networks variable.
6. NTP access, to the source defined in ntp_source variable.
7. HTTP access to AWS Instance Metadata and User Data endpoints for EC2 + ECS.

[infra scripts](amazon-ebs-builder/scripts/centos7/infra) - In addition to generic_scripts, the below scripts will run on ec2 AMI builds.
* 097-iptables.sh - configures the required iptable rules for an Infra EC2 node. These allow outbound web access for Infra services such as Jenkins.


base AMI Usage
------------

The following variables should be added to the [base](amazon-ebs-builder/CentOS7-base.json):

* aws_region: The AWS region where the AMI should be generated. Example: eu-west-2
* vpc_id: The VPC which you'd like the AMI to be built in. Example: vpc-43ed2c1a
* subnet_id: The Subnet which you'd like the AMI to be built in. Example: vpc-43ed2c1a
* owner_name: The owners name. Example: Burbank
* volume_size: The size of the OS Disk. Example: 20G

Running the base build:
```
# packer build CentOS7-base.json
```
Running the base build in debug mode:
```
# PACKER_LOG=1 packer build CentOS7-base.json
```

ec2 AMI Usage
------------

The following variables should be added to the [ec2](amazon-ebs-builder/CentOS7-ec2.json):

* aws_accountid: The AWS accountid, this is used to find the base AMI. Example: 123456789
* owner_name: The team name. Example: burbank
* os_version: OS version. Example: 7
* minor_version: Minor OS version. Example: .5.1804
* mirror_source: Source which the kickstart file will use to install the OS. Example: http://mirror.centos.org/centos/
* aws_instance_type: Instance type the AMI is built using. This can be a micro as the AMI works across all builds. Example: t2.micro
* ntp_source: chrony NTP source. Example: 169.254.169.123/32
* internal_cidr: Internal networks you wish IPTables to be locked down to, this adds SSH access and access to the app ports. Example: 1.2.3.4/8
* ipv4_forward: This should be set to 0 in ec2, but is required to be 1 for ECS.
* app_ports: The ports which require to be open within the 'internal_cidr'. Example: 443,8080,9100:9105"
* aws_networks: We're allowing internal AWS access by region. These can be obtained by doing something like the following for eu-west-2, RANGES=$(curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq .prefixes | jq '.[] | select(.region=="eu-west-2")' | jq 'select(.service=="AMAZON")' | jq .ip_prefix | cut -d '"' -f 2 | sort | uniq | tr "\n" "," | sed '$s/,$//')
Example: 18.130.0.0/16,18.175.0.0/16,35.176.0.0/15,35.178.0.0/15,52.144.209.192/26,52.144.209.64/26,52.144.211.128/26,52.144.211.192/31,52.144.211.194/31,52.144.211.196/31,52.144.211.198/31,52.144.211.200/31,52.144.211.202/31,52.56.0.0/16,52.92.88.0/22,52.93.138.252/32,52.93.138.253/32,52.93.139.252/32,52.93.139.253/32,52.94.112.0/22,52.94.15.0/24,52.94.198.144/28,52.94.248.192/28,52.94.32.0/20,52.94.48.0/20,52.95.148.0/23,52.95.150.0/24,52.95.253.0/24,54.239.0.240/28,54.239.100.0/23"
* ssh_allow: ssh allow groups. Example: sshaccess, ec2-user


Running the ec2 build:
```
# packer build CentOS7-ec2.json
```
Running the ec2 build in debug mode:
```
# PACKER_LOG=1 packer build CentOS7-ec2.json
```
ec2 AMI Usage
------------

The following variables should be added to the [ec2](amazon-ebs-builder/CentOS7-ec2.json):

* aws_accountid: The AWS accountid, this is used to find the base AMI. Example: 123456789
* owner_name: The team name. Example: burbank
* os_version: OS version. Example: 7
* minor_version: Minor OS version. Example: .5.1804
* mirror_source: Source which the kickstart file will use to install the OS. Example: http://mirror.centos.org/centos/
* aws_instance_type: Instance type the AMI is built using. This can be a micro as the AMI works across all builds. Example: t2.micro
* docker_version: docker version. Example: 17.12.1
* ntp_source: chrony NTP source. Example: 169.254.169.123/32
* internal_cidr: Internal networks you wish IPTables to be locked down to, this adds SSH access and access to the app ports. Example: 1.2.3.4/8
* ipv4_forward: This should be set to 0 in ec2, but is required to be 1 for ECS.
* app_ports: The ports which require to be open within the 'internal_cidr'. Example: 443,8080,9100:9105"
* aws_networks: We're allowing internal AWS access by region. These can be obtained by doing something like the following for eu-west-2, RANGES=$(curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq .prefixes | jq '.[] | select(.region=="eu-west-2")' | jq 'select(.service=="AMAZON")' | jq .ip_prefix | cut -d '"' -f 2 | sort | uniq | tr "\n" "," | sed '$s/,$//')
Example: 18.130.0.0/16,18.175.0.0/16,35.176.0.0/15,35.178.0.0/15,52.144.209.192/26,52.144.209.64/26,52.144.211.128/26,52.144.211.192/31,52.144.211.194/31,52.144.211.196/31,52.144.211.198/31,52.144.211.200/31,52.144.211.202/31,52.56.0.0/16,52.92.88.0/22,52.93.138.252/32,52.93.138.253/32,52.93.139.252/32,52.93.139.253/32,52.94.112.0/22,52.94.15.0/24,52.94.198.144/28,52.94.248.192/28,52.94.32.0/20,52.94.48.0/20,52.95.148.0/23,52.95.150.0/24,52.95.253.0/24,54.239.0.240/28,54.239.100.0/23"
* ssh_allow: ssh allow groups. Example: sshaccess, ec2-user


Running the ecs build:
```
# packer build CentOS7-ecs.json
```
Running the ecs build in debug mode:
```
# PACKER_LOG=1 packer build CentOS7-ecs.json
```

Notes
------------

An IAM role [ https://www.packer.io/docs/builders/amazon.html#using-an-iam-instance-profile ] can be utilised if this is to be integrated with Jenkins + Packer 1.2.3.

Cloudwatch should be implemented, only 3 days logs are maintained on the server. *** Needs to be templated to grab anything in /var/log/*

## Maintainer

Burbank Team

## Author

* **Stuart Tansley**

[Contribution guidelines for this project](CONTRIBUTING.md)

