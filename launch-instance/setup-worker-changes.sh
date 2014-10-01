#!/bin/bash

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
