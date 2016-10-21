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


# Always create new indexes in case the models have changed
# cd /opt/openstudio/server && bundle exec rspec --format html
# cd /opt/openstudio/server && bundle exec rspec spec/requests/pages_spec.rb --format html
cd /opt/openstudio/server && bundle exec rspec --format html; (( exit_status = exit_status || $? ))
cd /opt/openstudio/server && bundle exec rake rubocop:run; (( exit_status = exit_status || $? ))

exit $exit_status
