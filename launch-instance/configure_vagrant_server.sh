#!/bin/bash

# Vagrant Server Bootstrap File
# This script is used to configure the vagrant boxes in order to test and run the examples

# setup the passwordless ssh
cd /data/launch-instance && ./setup-ssh-keys-vagrant.expect
cp -f /data/launch-instance/ip_addresses_vagrant.template /data/launch-instance/ip_addresses
cd /data/launch-instance && ./setup-ssh-worker-nodes.sh ip_addresses

# need to setup the hosts file and the local paths for writing results

ENTRY="localhost localhost master"
FILE=/etc/hosts
if grep -q "$ENTRY" $FILE; then
  echo "entry already exists"
else
  sudo sh -c "echo $ENTRY >> /etc/hosts"
fi

# copy all the setup scripts to the appropriate home directory
cp /data/launch-instance/setup* ~
chmod 775 ~/setup*
chown vagrant:vagrant ~/setup*

# stop the various services that use mongo
sudo service delayed_job stop
sudo service apache2 stop
sudo service mongodb stop
# support the new mongodb version as well
sudo service mongod stop

# remove mongo db & add it back
sudo mkdir -p /mnt/mongodb/data
sudo chown mongodb:nogroup /mnt/mongodb/data
sudo rm -rf /var/lib/mongodb

# restart mongo
sudo service mongodb start
sudo service mongod start

# restart the rails application
sudo service apache2 stop
sudo service apache2 start

# Add in the database indexes after making the db directory
sudo chmod 777 /var/www/rails/openstudio/public
cd /var/www/rails/openstudio
rake db:purge
rake db:mongoid:create_indexes

# configure the application based worker data
cd /data/launch-instance && sudo ./configure_vagrant_worker_data.sh

# restart rserve
sudo service Rserve restart

# restart delayed jobs
sudo service delayed_job start

# Null out the logs
sudo cat /dev/null > /var/www/rails/openstudio/log/download.log
sudo cat /dev/null > /var/www/rails/openstudio/log/mongo.log
sudo cat /dev/null > /var/www/rails/openstudio/log/development.log
sudo cat /dev/null > /var/www/rails/openstudio/log/production.log
sudo cat /dev/null > /var/www/rails/openstudio/log/delayed_job.log
sudo cat /dev/null > /var/www/rails/openstudio/log/Rserve.log

#file flag the user_data has completed
cat /dev/null > ~/user_data_done
