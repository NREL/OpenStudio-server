#!/usr/bin/env bash

# Configure XVFB
Xvfb :10 -ac &
export DISPLAY=:10

# Arbitrary sleep to wait for other containers and xvfb to start if this was the first
for i in {1..10}
do
  echo "Waiting so other processes can start"
  sleep 1s
done

echo "Waiting for Mongo to start"
/usr/local/bin/wait-for-it --strict -t 0 db:27017

echo "Waiting for Redis to start"
/usr/local/bin/wait-for-it --strict -t 0 queue:6379

# Always create new indexes in case the models have changed
cd /opt/openstudio/server && bundle exec rspec; (( exit_status = exit_status || $? ))
cd /opt/openstudio/server && bundle exec rake rubocop:run; (( exit_status = exit_status || $? ))

exit $exit_status
