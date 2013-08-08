#!/bin/sh
mkdir /home/ubuntu/test

# Change Host
echo 50.16.146.112 ec2-50-16-146-112.compute-1.amazonaws.com master_hostname >> /etc/hosts

# Replace Hostname 
#echo "slave1" > /etc/hostname
#sudo hostname slave
#hostname
#replace hostname in /etc/hosts

# Restart Server
sudo service networking restart 
 



