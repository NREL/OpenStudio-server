#!/bin/sh

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

# Upgrade without a prompt! The second upgrade is just to make sure everyting was upgraded
# http://askubuntu.com/questions/146921/how-do-i-apt-get-y-dist-upgrade-without-a-grub-config-prompt
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
sudo apt-get upgrade -y

chmod +x /data/launch-instance/setup-cleanup-aws.sh
sudo /data/launch-instance/setup-cleanup-aws.sh
