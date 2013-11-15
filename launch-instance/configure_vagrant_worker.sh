#!/bin/bash

# Vagrant Worker Bootstrap File

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

# Force the generation of various directories that are in the EBS mnt
sudo rm -rf /mnt/openstudio/*
sudo mkdir -p /mnt/openstudio
sudo chmod -R 777 /mnt/openstudio

# Copy worker node files to the run directory location
cp -rf /data/worker-nodes/* /mnt/openstudio/

# Unzip the rails-models
cd /mnt/openstudio/rails-models && unzip -o rails-models.zip

# rename the mongoid-vagrant template to mongoid.yml
mv /mnt/openstudio/rails-models/mongoid-vagrant.yml /mnt/openstudio/rails-models/mongoid.yml

# Run this once more to make sure all files have world writable permissions (for now)
sudo chmod -R 777 /mnt/openstudio

#file flag the user_data has completed
cat /dev/null > ~/user_data_done


