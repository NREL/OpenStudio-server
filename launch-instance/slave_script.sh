#!/bin/sh
mkdir /home/ubuntu/test

# Change Host
echo 50.17.161.61 ec2-50-17-161-61.compute-1.amazonaws.com master_hostname >> /etc/hosts

# Replace Hostname 
#echo "slave1" > /etc/hostname
#sudo hostname slave
#hostname
#replace hostname in /etc/hosts

# Restart Server
sudo service networking restart 
 



