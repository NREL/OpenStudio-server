#!/bin/sh
mkdir /home/ubuntu/test

# Change Host
#echo 75.101.169.112 MASTER_DNS master_name >> /etc/hosts
echo 75.101.169.112 master_name >> /etc/hosts

# Replace Hostname 
#echo "slave1" > /etc/hostname
#sudo hostname slave
#hostname
#replace hostname in /etc/hosts

# Restart Server
sudo service networking restart 
 



