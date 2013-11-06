#!/bin/bash

# This script is used to configure the vagrant boxes in order to test and run the examples

# setup the passwordless ssh
cd /data/launch-instance && ./setup-ssh-keys-vagrant.expect
cp -f /data/launch-instance/ip_addresses_vagrant.template /data/launch-instance/ip_addresses
cd /data/launch-instance && ./setup-ssh-worker-nodes.sh ip_addresses

# need to setup the hosts file and the local paths for writing results
sudo /data/launch-instance/server_script_vagrant.sh

# rename the mongoid-vagrant template to mongoid.yml
mv /mnt/openstudio/rails-models/mongoid-vagrant.yml /mnt/openstudio/rails-models/mongoid.yml

#create mongodb dir
sudo rm -rf /mnt/mongodb/data
sudo mkdir -p /mnt/mongodb/data
sudo chown mongodb:nogroup /mnt/mongodb/data
sudo service mongodb restart
sudo service delayed_job restart
sudo rm -rf /var/lib/mongodb