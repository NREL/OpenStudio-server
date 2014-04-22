#!/bin/bash

# Force the generation of various directories that are in the EBS mnt
sudo rm -rf /mnt/openstudio
sudo mkdir -p /mnt/openstudio
sudo chown -R vagrant:www-data /mnt/openstudio
sudo chmod -R 775 /mnt/openstudio

# save application files into the right directory
cp -rf /data/worker-nodes/* /mnt/openstudio/

# copy over the models needed for mongo
cd /mnt/openstudio/rails-models && unzip -o rails-models.zip

# rename the mongoid-vagrant template to mongoid.yml which is unpacked with unzip
mv /mnt/openstudio/rails-models/mongoid-vagrant.yml /mnt/openstudio/rails-models/mongoid.yml

# rerun the permissions after unzipping the files
sudo chown -R vagrant:www-data /mnt/openstudio 
sudo find /mnt/openstudio -type d -print0 | xargs -0 chmod 775
sudo find /mnt/openstudio -type f -print0 | xargs -0 chmod 664

