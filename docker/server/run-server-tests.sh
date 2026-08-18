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
# Socket-level specs for the persistent worker->web HTTP client. Fast, no stack needed.
cd /opt/openstudio/server && bundle exec rspec spec/lib/os_http_spec.rb; (( exit_status = exit_status || $? ))
# Unit specs for the Resque::Worker#reconnect hardening (retry Redis::CommandError,
# e.g. "max number of clients reached"). Resque only loads under RAILS_ENV=docker,
# so they run here. Fast, no stack needed.
cd /opt/openstudio/server && bundle exec rspec spec/lib/resque_reconnect_retry_spec.rb; (( exit_status = exit_status || $? ))
# Model/request specs for seed.zip upload validation + InitializeAnalysis failure handling (issue #841).
# These need only rails+mongo, so run them first - they are fast and leave the db empty.
cd /opt/openstudio/server && bundle exec rspec spec/models/analysis_init_spec.rb spec/requests/analyses_upload_spec.rb; (( exit_status = exit_status || $? ))
# Job-level integration specs for RunSimulateDataPoint (dj + resque inline). They run the
# full job - including the persistent worker->web HTTP client - against an in-process app.
# Their after(:all) hooks destroy projects/paperclip assets so later specs start empty (#841).
cd /opt/openstudio/server && bundle exec rspec spec/features/dj_run_simulation_data_point_spec.rb; (( exit_status = exit_status || $? ))
cd /opt/openstudio/server && bundle exec rspec spec/features/resque_run_simulation_data_point_spec.rb; (( exit_status = exit_status || $? ))
# The in-process spec apps above run as root and can leave a root-owned 0755
# assets/data_points dir; remove it so the live app (nobody) can recreate it
# writable, or the docker_stack specs below fail on result-file uploads (#841).
rm -rf /mnt/openstudio/server/assets/data_points
# Run only the algorithm specs. The other features/*_spec files should probably disappear and capybara/gecko
# can be removed.
cd /opt/openstudio/server && bundle exec rspec spec/features/docker_stack_custom_gems.rb; (( exit_status = exit_status || $? ))
cd /opt/openstudio/server && bundle exec rspec spec/features/docker_stack_test_apis_spec.rb; (( exit_status = exit_status || $? ))
cd /opt/openstudio/server && bundle exec rspec spec/features/docker_stack_algo_spec.rb; (( exit_status = exit_status || $? ))
cd /opt/openstudio/server && bundle exec rspec spec/features/docker_stack_requeue_spec.rb; (( exit_status = exit_status || $? ))
echo "SKIP_URBANOPT_ALGO: $SKIP_URBANOPT_ALGO"
if ! $SKIP_URBANOPT_ALGO -eq true
then
  cd /opt/openstudio/server && bundle exec rspec spec/features/docker_stack_urbanopt_algo_spec.rb; (( exit_status = exit_status || $? ))
fi
#cd /opt/openstudio/server && bundle exec rake rubocop:run; (( exit_status = exit_status || $? ))

exit $exit_status
