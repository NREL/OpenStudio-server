#!/bin/sh

# Allow password-based authentication
sudo sed -i 's/PasswordAuthentication.no/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config
echo StrictHostKeyChecking no > /home/ubuntu/.ssh/config
sudo service ssh restart

# Set a default password and unlock
echo -e "ubuntu\nubuntu" | sudo passwd ubuntu
sudo passwd -u ubuntu

# Clean up files to remove history
cat /dev/null > ~/.ssh/authorized_keys
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
sudo rm -f /data/launch-instance/*.pem
sudo rm -f /data/launch-instance/*.log
sudo rm -f /data/launch-instance/*.json
sudo rm -f /data/launch-instance/*.yml
sudo rm -f /data/worker-nodes/README.md
sudo rm -f /data/worker-nodes/rails-models/mongoid-vagrant.yml
sudo rm -rf /var/chef
sudo cat /dev/null > ~/.bash_history && history -c

# Clean up apt
sudo apt-get clean

