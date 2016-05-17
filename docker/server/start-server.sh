#!/usr/bin/env bash

# Always create new indexes in case the models have changed
cd /srv && bundle exec rake db:mongoid:create_indexes

# Start delayed job on the server node for analyses and background jobs
bin/delayed_job -i server --queue=analyses,background start

/opt/nginx/sbin/nginx
