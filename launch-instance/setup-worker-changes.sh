#!/bin/sh

# Allow password-based authentication
sudo sed -i 's/PasswordAuthentication.no/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config
echo StrictHostKeyChecking no > .ssh/config
sudo service ssh restart

# Upgrade any remaining packages and call the cleanup scripts
sudo apt-get upgrade -y
chmod +x /data/launch-instance/setup-cleanup-aws.sh
sudo /data/launch-instance/setup-cleanup-aws.sh

# Unlock the ubuntu password
sudo passwd -u ubuntu
