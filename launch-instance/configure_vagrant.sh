#!/bin/bash

# This script is used to configure the vagrant boxes in order to test and run the examples

./setup-ssh-keys-vagrant.sh
./setup-ssh-worker-nodes.sh ip_address_vagrant

# need to setup the hosts file

