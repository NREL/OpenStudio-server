sudo rm -rf /mnt/openstudio/*
sudo mkdir -p /mnt/openstudio
sudo chmod -R 777 /mnt/openstudio

# Copy worker node files to the run directory location
cp -rf /data/worker-nodes/* /mnt/openstudio/

# Unzip the rails-models
cd /mnt/openstudio/rails-models && unzip -o rails-models.zip

# rename the mongoid-vagrant template to mongoid.yml
mv /mnt/openstudio/rails-models/mongoid-vagrant.yml /mnt/openstudio/rails-models/mongoid.yml

# Run this once more to make sure all files have world writable permissions (for now)
sudo chmod -R 777 /mnt/openstudio
