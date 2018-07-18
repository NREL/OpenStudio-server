#!/usr/bin/env bash

echo "Waiting for Mongo to start"
/usr/local/bin/wait-for-it --strict -t 0 db:27017

echo "Waiting for Redis to start"
/usr/local/bin/wait-for-it --strict -t 0 queue:6379

# Always create new indexes in case the models have changed
cd /opt/openstudio/server && bundle exec rake db:mongoid:create_indexes

# The memfix-controller seems to have causes some issues with NRCan, need to revisit.
# https://github.com/NREL/OpenStudio-server/issues/348
ruby /usr/local/lib/memfix-controller.rb start

/opt/nginx/sbin/nginx
