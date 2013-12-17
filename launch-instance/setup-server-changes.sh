#!/bin/sh

sudo sed -i 's/PasswordAuthentication.no/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config
echo StrictHostKeyChecking no > /home/ubuntu/.ssh/config
sudo service ssh restart
cd /var/www/rails/openstudio
rake db:purge
rake db:mongoid:create_indexes
rm -rf /mnt/openstudio
sudo apt-get upgrade -y
chmod +x /data/launch-instance/setup-cleanup-aws.sh
sudo /data/launch-instance/setup-cleanup-aws.sh
