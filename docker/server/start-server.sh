#!/usr/bin/env bash

# Always create new indexes in case the models have changed
cd /srv && bundle exec rake db:mongoid:create_indexes

/opt/nginx/sbin/nginx
