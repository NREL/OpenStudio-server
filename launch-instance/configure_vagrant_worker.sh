#!/bin/bash

# This script is used to configure the vagrant boxes (workers) in order to test and run the examples

# need to setup the hosts file
sudo ./slave_script_vagrant.sh

# make sure that the openstudio directory for simulations exists and is writable
sudo mkdir -p /mnt/openstudio
sudo chmod 777 /mnt/openstudio

