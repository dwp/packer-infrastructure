#!/bin/sh -x
#
set -e
set -u

IPT="/sbin/iptables"

# AWS Instance Metadata and User Data endpoint
META_EC2="169.254.169.254"

echo "flushing iptables rules"
$IPT -F
$IPT -X
$IPT -t nat -F
$IPT -t nat -X
$IPT -t mangle -F
$IPT -t mangle -X

echo "Set local DHCP"
$IPT -A INPUT -p udp -m udp --dport 67:78 -j ACCEPT

## Allow DNS looksups in AWS
for ip in $IP_RANGE
do
	echo "Allowing DNS lookups (tcp, udp port 53) to server '$ip'"
	$IPT -A OUTPUT -p udp -d $ip --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A INPUT  -p udp -s $ip --sport 53 -m state --state ESTABLISHED     -j ACCEPT
	$IPT -A OUTPUT -p tcp -d $ip --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A INPUT  -p tcp -s $ip --sport 53 -m state --state ESTABLISHED     -j ACCEPT
done

echo "allow all and everything on localhost"
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT
$IPT -A INPUT -s 127.0.0.0/8 -j DROP


#######################################################################################################
## Global rules
#######################################################################################################

for ip in $IP_RANGE
do
	echo "Allowing new and established incoming connections to ports defined in variable"
	$IPT -A INPUT  -p tcp -s "$ip" -m multiport --dports "$APP_PORTS" -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A OUTPUT -p tcp -s "$ip" -m multiport --sports "$APP_PORTS" -m state --state ESTABLISHED     -j ACCEPT
done

for ip in $IP_RANGE
do
	echo "Allow incomming ssh connections to port 22 from internal networks"
	$IPT -A INPUT -p tcp -s "$ip" --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED     -j ACCEPT
done

for ip in $AWS
do
	echo "Allow connection to '$ip' on port 443"
	$IPT -A OUTPUT -p tcp -m tcp -d "$ip" --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A INPUT  -p tcp -m tcp  -s "$ip" --sport 443 -m state --state ESTABLISHED     -j ACCEPT
done

for ip in $NTP_SOURCE
do
	echo "Allow outgoing connections to port 123 in AWS"
	$IPT -A OUTPUT -p udp --dport 123 -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A INPUT  -p udp -s "$ip" --sport 123 -m state --state ESTABLISHED     -j ACCEPT
done

for ip in $META_EC2
do
	$IPT -A OUTPUT -p tcp -m tcp -d "$ip" --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPT -A INPUT  -p tcp -m tcp  -s "$ip" --sport 80 -m state --state ESTABLISHED     -j ACCEPT
done


# Log before dropping
$IPT -A FORWARD -j LOG  -m limit --limit 12/min --log-level 4 --log-prefix "IP FORWARD drop: "

$IPT -A INPUT  -j LOG  -m limit --limit 12/min --log-level 4 --log-prefix 'IP INPUT drop: '

$IPT -A OUTPUT -j LOG  -m limit --limit 12/min --log-level 4 --log-prefix 'IP OUTPUT drop: '

echo "Set default policy to 'DROP'"
$IPT -P INPUT   DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT  DROP

echo "Ensuring iptables is enable + saving configuration"
/bin/systemctl enable iptables

/sbin/service iptables save

exit 0
