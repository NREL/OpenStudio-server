#!/usr/bin/env bash

# Configure XVFB
export DISPLAY=:99.0
sh -e /etc/init.d/xvfb start

# Arbitrary sleep to wait for other containers and xvfb to start if this was the first
for i in {1..10}
do
  echo "Waiting so other processes can start"
  sleep 1s
done


# Always create new indexes in case the models have changed
cd /opt/openstudio/server && bundle exec rspec --format html
cd /opt/openstudio/server && bundle exec rake rubocop:run

