#!/bin/sh
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1


# Change Host File Entries
ENTRY="localhost localhost master"
FILE=/etc/hosts
if grep -q "$ENTRY" $FILE; then
  echo "entry already exists"
else
  sudo sh -c "echo $ENTRY >> /etc/hosts"
fi

# Some debugging
echo whoami
echo pwd

# copy all the setup scripts to the appropriate home directory
cp /data/launch-instance/setup* ~
chmod 775 ~/setup*

# Force the generation of various directories that are in the EBS mnt
sudo rm -rf /mnt/openstudio
sudo mkdir -p /mnt/openstudio
sudo chmod 777 /mnt/openstudio
sudo chmod 777 /var/www/rails/openstudio/public

# save some files into the right directory
cp /data/prototype/pat/SimulateDataPoint.rb /mnt/openstudio/
cp /data/prototype/pat/CommunicateResults_Mongo.rb /mnt/openstudio/

# copy over the models needed for mongo
mkdir -p /mnt/openstudio/rails-models
cp /data/prototype/pat/rails-models.zip /mnt/openstudio/rails-models/
cd /mnt/openstudio/rails-models
unzip -o rails-models.zip