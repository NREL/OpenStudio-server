#!/usr/bin/env bash

# Arbitrary sleep to wait for other containers to start if this was the first
sleep 5

for i in {1..5}
do
  echo "Waiting so other processes can start"
  sleep 1s
done


# Always create new indexes in case the models have changed
cd /opt/openstudio/server && bundle exec rspec ./spec/models/run_simulation_data_point_spec.rb:49
