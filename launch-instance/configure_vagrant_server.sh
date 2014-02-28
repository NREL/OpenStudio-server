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

# stop the various services that use mongo
sudo service delayed_job stop
sudo service apache2 stop
sudo service mongodb stop

# remove mongo db & add it back
# sudo rm -rf /mnt/mongodb/data
sudo mkdir -p /mnt/mongodb/data
sudo chown mongodb:nogroup /mnt/mongodb/data
sudo rm -rf /var/lib/mongodb

# restart mongo
sudo service mongodb start

# restart the rails application
sudo service apache2 start

# Add in the database indexes after making the db directory
cd /var/www/rails/openstudio
rake db:purge
rake db:mongoid:create_indexes

# restart delayed jobs
sudo service delayed_job start

# restart rserve
sudo service Rserve restart

# Copy over the worker data to the run directory
cd /data/launch-instance && ./configure_vagrant_worker_data.sh

# Null out the logs
sudo cat /dev/null > /var/www/rails/openstudio/log/download.log
sudo cat /dev/null > /var/www/rails/openstudio/log/mongo.log
sudo cat /dev/null > /var/www/rails/openstudio/log/development.log
sudo cat /dev/null > /var/www/rails/openstudio/log/production.log
sudo cat /dev/null > /var/www/rails/openstudio/log/delayed_job.log
sudo cat /dev/null > /var/www/rails/openstudio/log/Rserve.log
