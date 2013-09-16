#!/bin/sh
#mkdir /home/ubuntu/test

# Change Host
echo localhost localhost master >> /etc/hosts

# Replace Hostname 
#echo "slave1" > /etc/hostname
#sudo hostname slave
#hostname
#replace hostname in /etc/hosts

# Restart Server
# NL Remove sudo on this command as you should already be sudo
service networking restart
 



