#!/bin/sh

sudo sed -i 's/PasswordAuthentication.no/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config
echo StrictHostKeyChecking no > .ssh/config
sudo service ssh restart
sudo apt-get upgrade -y
cd /data/launch-instance
chmod 777 setup-cleanup-aws.sh
sudo ./setup-cleanup-aws.sh