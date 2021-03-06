#!/bin/bash

#function to get IP address of local computer
function getlocalip()
{
    local LANG=en_US
	/sbin/ifconfig ${1:-eth0} | awk '/inet addr/ {print $2}' | awk -F: '{print $2}';
}

#function to get bcast address for local computer
function getbcast()
{
    local LANG=en_US
	/sbin/ifconfig ${1:-eth0} | awk '/Bcast/ {print $3}' | awk -F: '{print $2}';
}

#function to get network mask for local computer
function getnetmask()
{
    local LANG=en_US
	/sbin/ifconfig ${1:-eth0} | awk '/Mask/ {print $4}' | awk -F: '{print $2}';
}

# function to prepare config file for setting static ip address
# $1 - full path to config file
# $2 - hostname
# $3 - domain
# $4 - [optional] address of dns server
function configeth0 {
	localip=`getlocalip`
	echo "DEVICE=eth0" > $1
	echo "BOOTPROTO=static" >> $1
	echo "ONBOOT=yes" >> $1
	echo "IPADDR=$localip" >> $1
	echo "BROADCAST=`getbcast`" >> $1
	echo "NETMASK=`getnetmask`" >> $1
	if [ ! -z $4 ]
	then
		echo "DNS1=$4" >> $1
        # set new dns server
        echo "nameserver $4" > /etc/resolv.conf
	fi

	mv /etc/sysconfig/network /etc/sysconfig/network.bak
	cat /etc/sysconfig/network.bak | grep -v HOSTNAME > /etc/sysconfig/network
	echo "HOSTNAME=$2.$3" >> /etc/sysconfig/network
	
	echo "$localip $2.$3 $2" >> /etc/hosts
	hostname "$2.$3"
}

function printhelp()
{
	echo "Script for configuring machine for installation and usage of freeipa-client."
	echo "Usage: ./freeipa-server-install.sh -c hostname -d domain [-n ip-addr-of-dns][-p passwd][-s serverhostname]"

	echo "Required arguments:"
	echo "-c hostname -- specifiy hostname of freeipaserver"
	echo "-d domain -- specify domain of freeipaserver"
	echo "-p passwd -- specify password for enrolling machine into freeipa"
	echo "-n ip-addr-of-dns -- specify ip address of dns server"
	echo "-s serverhostname -- specify server hostname"
}


clientip=`getlocalip`
eth0conf=/etc/sysconfig/network-scripts/ifcfg-eth0
dns=""
serverhostname=""
domain=""
clienthostname=""
password=""

while getopts "n:d:s:c:p:h" opt; do
	case $opt in
		n) dns=$OPTARG
			;;
		s) serverhostname=$OPTARG
			;;
		d) domain=$OPTARG
			;;
		c) clienthostname=$OPTARG
			;;
		p) password=$OPTARG
			;;
		h) printhelp
		   exit 0
			;;
		\?) echo "Unknown parameter used!"
		    exit 1
			;;
	esac
done

if [ -z $serverhostname ]
then
	echo "You must specify server hostname."
	exit 1
fi

if [ -z $domain ]
then
	echo "You must specify domain."
	exit 1
fi

if [ -z $password ]
then
	echo "You must specify password for enrollment."
	exit 1
fi

if [ -z $clienthostname ]
then
	echo "You must specify client hostname."
	exit 1
fi

service NetworkManager stop
chkconfig NetworkManager off
chkconfig network on

configeth0 $eth0conf $clienthostname $domain $dns

service network restart

# run the install
ipa-client-install --server=$serverhostname.$domain --domain=$domain --hostname=$clienthostname.$domain --password=$password --enable-dns-updates --mkhomedir -U
# need to reboot in order to allow ipademo user using graphical desktop environmnet
reboot
