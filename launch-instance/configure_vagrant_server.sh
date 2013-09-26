#!/bin/bash

# This script is used to configure the vagrant boxes in order to test and run the examples

# setup the passwordless ssh
cd /data/launch-instance && ./setup-ssh-keys-vagrant.expect
cd /data/launch-instance && ./setup-ssh-worker-nodes.sh ip_addresses_vagrant

# need to setup the hosts file
sudo /data/launch-instance/master_script.sh

# make sure that the openstudio directory for simulations exists and is writable
sudo mkdir -p /mnt/openstudio
sudo chmod 777 /mnt/openstudio

# set some of the rails variables that are needed

