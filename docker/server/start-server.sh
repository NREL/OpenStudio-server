#!/usr/bin/env bash

# Always create new indexes in case the models have changed
cd /opt/openstudio/server && bundle exec rake db:mongoid:create_indexes

ruby /usr/local/bin/memfix-controler.rb start

/opt/nginx/sbin/nginx
