#!/bin/sh

sudo sed -i 's/PasswordAuthentication.no/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config
echo StrictHostKeyChecking no > .ssh/config
sudo service ssh restart
cd /var/www/rails/openstudio
rake db:purge
rake db:mongoid:create_indexes
rm -rf /mnt/openstudio
sudo apt-get upgrade -y
cd /data/launch-instance
chmod 777 setup-cleanup-aws.sh
sudo ./setup-cleanup-aws.sh