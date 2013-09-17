#!/bin/bash

# This script is used to configure the vagrant boxes in order to test and run the examples

# setup the passwordless ssh
./setup-ssh-keys-vagrant.expect
./setup-ssh-worker-nodes.sh ip_address_vagrant

# need to setup the hosts file
sudo ./master_script.sh

# make sure that the openstudio directory for simulations exists and is writable
sudo mkdir -p /mnt/openstudio
sudo chmod 777 /mnt/openstudio

# set some of the rails variables that are needed

