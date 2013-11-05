#!/bin/bash

# This script is used to configure the vagrant boxes in order to test and run the examples

# setup the passwordless ssh
cd /data/launch-instance && ./setup-ssh-keys-vagrant.expect
cp -f /data/launch-instance/ip_addresses_vagrant.template /data/launch-instance/ip_addresses
cd /data/launch-instance && ./setup-ssh-worker-nodes.sh ip_addresses

# need to setup the hosts file
sudo /data/launch-instance/server_script_vagrant.sh

# make sure that the openstudio directory for simulations exists and is writable
sudo mkdir -p /mnt/openstudio
sudo chmod 777 /mnt/openstudio
sudo rm -rf /mnt/mongodb/data
sudo mkdir -p /mnt/mongodb/data
sudo chown mongodb:nogroup /mnt/mongodb/data
sudo service mongodb restart
sudo service delayed_job restart
sudo rm -rf /var/lib/mongodb