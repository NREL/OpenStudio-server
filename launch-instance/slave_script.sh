#!/bin/sh
mkdir /home/ubuntu/test

# Change Host
#echo 23.22.155.139 MASTER_DNS master_name >> /etc/hosts
echo 23.22.155.139 master_name >> /etc/hosts

# Replace Hostname 
#echo "slave1" > /etc/hostname
#sudo hostname slave
#hostname
#replace hostname in /etc/hosts

# Restart Server
sudo service networking restart 
 



