#!/bin/sh
mkdir /home/ubuntu/test

# Change Host
#echo 23.21.31.195 MASTER_DNS master_name >> /etc/hosts
echo 23.21.31.195 master_name >> /etc/hosts

# Replace Hostname 
#echo "slave1" > /etc/hostname
#sudo hostname slave
#hostname
#replace hostname in /etc/hosts

# Restart Server
sudo service networking restart 
 



