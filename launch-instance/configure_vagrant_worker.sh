#!/bin/bash

# Vagrant Worker Bootstrap File
# File used to configure worker nodes on vagrant

# Change Host File Entries
ENTRY="192.168.33.10 os-server"
FILE=/etc/hosts
if grep -q "$ENTRY" $FILE; then
  echo "entry already exists"
else
  sudo sh -c "echo $ENTRY >> /etc/hosts"
fi

# copy all the setup scripts to the appropriate home directory -- Not needed on vagrant
#cp /data/launch-instance/setup* ~
#chmod 775 ~/setup*
#chown ubuntu:ubuntu /home/ubuntu/setup*

# configure the application based worker data
cd /data/launch-instance && sudo ./configure_vagrant_worker_data.sh

#file flag the user_data has completed
cat /dev/null > ~/user_data_done


              
