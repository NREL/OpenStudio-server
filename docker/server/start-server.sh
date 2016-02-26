#!/usr/bin/env bash

cd /srv && bundle exec rake db:mongoid:drop
cd /srv && bundle exec rake db:mongoid:create_indexes
cd /srv && bundle exec rake setup:docker
service supervisord start
# Wait for supervisor to start?

/opt/nginx/sbin/nginx
