#!/bin/sh
mkdir /home/ubuntu/test

# Change Host
echo 54.226.162.86 ec2-54-226-162-86.compute-1.amazonaws.com master_hostname >> /etc/hosts

# Replace Hostname 
#echo "slave1" > /etc/hostname
#sudo hostname slave
#hostname
#replace hostname in /etc/hosts

# Restart Server
sudo service networking restart 
 



