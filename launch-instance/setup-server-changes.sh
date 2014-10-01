#!/bin/bash

# Reset permissions on files - add sticky bit for public data
sudo chown -R ubuntu.www-data /var/www/rails/openstudio
sudo chown -R ubuntu.www-data /var/www/rails/public
sudo chmod -R g+w /var/www/rails/openstudio/public
sudo chmod +t /var/www/rails/openstudio/public
sudo chmod -R g+w /var/www/rails/openstudio/tmp
cd /var/www/rails/openstudio
rake db:purge
rake db:mongoid:create_indexes
rm -rf /mnt/openstudio

# Upgrade any remaining packages and call the cleanup scripts
sudo apt-get update -y

# Upgrade distribution without a prompt! The second upgrade is just to make sure everyting was upgraded
# http://askubuntu.com/questions/146921/how-do-i-apt-get-y-dist-upgrade-without-a-grub-config-prompt
# Disabled for now because if we upgrade the distribution, then we need to update the grub and that I can't
# figure out how to make this happen.  If a new kernel is released it is best to look for a new base AMI from
# this site: http://cloud-images.ubuntu.com/locator/ec2/

# sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
# sudo apt-get upgrade -y

chmod +x /data/launch-instance/setup-cleanup-aws.sh
sudo /data/launch-instance/setup-cleanup-aws.sh
