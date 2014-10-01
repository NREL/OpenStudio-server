#!/bin/bash

# Upgrade any remaining packages and call the cleanup scripts
sudo apt-get update -y

# Upgrade without a prompt! The second upgrade is just to make sure everyting was upgraded
# http://askubuntu.com/questions/146921/how-do-i-apt-get-y-dist-upgrade-without-a-grub-config-prompt
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
sudo apt-get upgrade -y

chmod +x /data/launch-instance/setup-cleanup-aws.sh
sudo /data/launch-instance/setup-cleanup-aws.sh
