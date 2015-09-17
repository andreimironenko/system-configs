#! /bin/bash

# Enabling gateway for the single IP address of OBC-SAE. This allows the central
# on-board computer to query SNMP information from network devices.

if [ ! -f /etc/pre-post-update.conf ] ; then
	exit -1
fi 

source /etc/pre-post-update.conf


iptables -F
iptables -A INPUT -s $obcsae_ip_addr -j ACCEPT
iptables-save 

echo 1 > /proc/sys/net/ipv4/ip_forward


exit 0