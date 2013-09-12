#!/bin/sh
mkdir /home/ubuntu/test

# Change Host
#echo 107.22.132.150 MASTER_DNS master_name >> /etc/hosts
echo 107.22.132.150 master_name >> /etc/hosts

# Replace Hostname 
#echo "slave1" > /etc/hostname
#sudo hostname slave
#hostname
#replace hostname in /etc/hosts

# Restart Server
sudo service networking restart 
 



