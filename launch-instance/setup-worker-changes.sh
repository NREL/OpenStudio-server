#!/bin/sh

# Upgrade any remaining packages and call the cleanup scripts
sudo apt-get upgrade -y
chmod +x /data/launch-instance/setup-cleanup-aws.sh
sudo /data/launch-instance/setup-cleanup-aws.sh
