#!/bin/bash

# This script is used to configure the vagrant boxes (workers) in order to test and run the examples

# need to setup the hosts file
sudo ./slave_script_vagrant.sh

# make sure that the openstudio directory for simulations exists and is writable (first blow away)
sudo rm -rf /mnt/openstudio
sudo mkdir -p /mnt/openstudio
sudo chmod 777 /mnt/openstudio

# save some files into the right directory
cp /data/prototype/pat/SimulateDataPoint.rb /mnt/openstudio/
cp /data/prototype/pat/CommunicateResults_Mongo.rb /mnt/openstudio/

# copy over the models needed for mongo
mkdir -p /mnt/openstudio/rails-models
cp /data/prototype/pat/rails-models.zip /mnt/openstudio/rails-models/
cd /mnt/openstudio/rails-models
unzip rails-models.zip

# send over the mongoid.yml file
cp /data/prototype/pat/mongoid.yml /mnt/openstudio/rails-models/

# eventually make this the file from the POST
cp /data/prototype/pat/analysis.zip /mnt/openstudio/
cd /mnt/openstudio
unzip analysis.zip





