#!/bin/bash

# Remove the snow.log
sudo rm -f /tmp/snow.log

# Force the generation of various directories that are in the EBS mount
sudo rm -rf /mnt/openstudio
sudo mkdir -p /mnt/openstudio
sudo chown -R vagrant:www-data /mnt/openstudio
sudo chmod -R 775 /mnt/openstudio

# save application files into the right directory
sudo rsync -a --chown vagrant:www-data --exclude Gemfile.lock /data/worker-nodes/ /mnt/openstudio/

# install workflow dependencies
# note: vagrant/ubuntu are now members of rbenv but it still doesn't work to not call sudo on bundle
cd /mnt/openstudio && sudo bundle

# copy over the models needed for mongo
cd /mnt/openstudio/rails-models && sudo unzip -o rails-models.zip -d models

# rename the mongoid-vagrant template to mongoid.yml which is unpacked with unzip
sudo mv /mnt/openstudio/rails-models/mongoid-vagrant.yml /mnt/openstudio/rails-models/mongoid.yml

# rerun the permissions after unzipping the files
sudo chown -R vagrant:www-data /mnt/openstudio 
sudo find /mnt/openstudio -type d -print0 | xargs -0 chmod 775
sudo find /mnt/openstudio -type f -print0 | xargs -0 chmod 664
