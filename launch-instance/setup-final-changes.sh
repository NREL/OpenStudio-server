#!/bin/bash

echo "Running setup-final-changes.sh"

# Allow password-based authentication
sudo sed -i 's/PasswordAuthentication.no/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config
echo StrictHostKeyChecking no > /home/ubuntu/.ssh/config
sudo service ssh restart

# Set a default password and unlock
echo -e "ubuntu\nubuntu" | sudo passwd ubuntu
sudo passwd -u ubuntu

# Remove authorized keys
sudo shred -u /home/ubuntu/.ssh/authorized_keys
sudo shred -u /root/.ssh/authorized_keys

# Clean up files to remove history
sudo cat /dev/null > /var/www/rails/openstudio/log/download.log
sudo cat /dev/null > /var/www/rails/openstudio/log/mongo.log
sudo cat /dev/null > /var/www/rails/openstudio/log/development.log
sudo cat /dev/null > /var/www/rails/openstudio/log/production.log
sudo cat /dev/null > /var/www/rails/openstudio/log/delayed_job.log
sudo rm -f /var/www/rails/openstudio/log/test.log
sudo rm -rf /var/www/rails/openstudio/public/assets/*
sudo rm -rf /var/www/rails/openstudio/tmp/*
sudo -- su -c 'cat /dev/null > /var/log/auth.log'
sudo -- su -c 'cat /dev/null > /var/log/lastlog'
sudo -- su -c 'cat /dev/null > /var/log/kern.log'
sudo -- su -c 'cat /dev/null > /var/log/boot.log'
sudo -- su -c 'cat /dev/null > /var/log/mongodb/mongodb.log'
sudo -- su -c 'cat /dev/null > /var/log/apache2/error.log'
sudo shred -u /data/launch-instance/*.pem
sudo shred -u /data/launch-instance/*.log
sudo shred -u /data/launch-instance/*.json
sudo shred -u /data/launch-instance/*.yml
sudo shred -u /data/worker-nodes/README.md
sudo shred -u /data/worker-nodes/rails-models/mongoid-vagrant.yml
sudo rm -rf /var/chef
sudo -- su ubuntu -c 'shred -u ~/.*history && history -c'
sudo -- su -c 'shred -u ~/.*history && history -c'
