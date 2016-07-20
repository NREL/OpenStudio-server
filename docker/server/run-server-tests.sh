#!/usr/bin/env bash

echo "here"
echo "here"
echo "here"
echo "here"
echo "here"
echo "here"
echo "here"
echo "here"
echo "here"
echo "here"
echo "here"
echo "here"
echo "here"

# Arbitrary sleep to wait for other containers to start if this was the first
sleep 30

# Always create new indexes in case the models have changed
cd /opt/openstudio/server && bundle exec rspec ./spec/models/run_simulation_data_point_spec.rb:49
