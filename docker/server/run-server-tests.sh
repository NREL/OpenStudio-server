#!/usr/bin/env bash

# This file is really running integration tests since it requires that a full stack has been created.

echo "Waiting for Mongo to start"
/usr/local/bin/wait-for-it --strict -t 0 db:27017

echo "Waiting for Redis to start"
/usr/local/bin/wait-for-it --strict -t 0 queue:6379

echo "Wait for the web service to be up"
/usr/local/bin/wait-for-it --strict -t 0 web:80

# Arbitrary sleep to wait for other containers and xvfb to start if this was the first
for i in {1..10}
do
  echo "Waiting so other processes can start"
  sleep 1s
done

#cd /opt/openstudio/server && bundle exec rspec; (( exit_status = exit_status || $? ))
# Run only the alorgithm specs. The other features/*_spec files should probably disappear and capybara/gecko
# can be removed.
cd /opt/openstudio/server && bundle exec rspec spec/features/openstudio_algo_spec.rb; (( exit_status = exit_status || $? ))
#cd /opt/openstudio/server && bundle exec rake rubocop:run; (( exit_status = exit_status || $? ))

exit $exit_status
