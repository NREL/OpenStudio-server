#!/bin/sh

sudo sed -i 's/PasswordAuthentication.no/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config
echo StrictHostKeyChecking no > .ssh/config
sudo service ssh restart
sudo apt-get upgrade -y
chmod +x /data/launch-instance/setup-cleanup-aws.sh
sudo /data/launch-instance/setup-cleanup-aws.sh
sudo passwd -u ubuntu
