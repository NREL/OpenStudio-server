#!/usr/bin/env bash

echo "Waiting for Mongo to start"
/usr/local/bin/wait-for-it --strict -t 0 db:27017

echo "Waiting for Redis to start"
/usr/local/bin/wait-for-it --strict -t 0 queue:6379

# Only start a single worker when calling this script (do not use resque:workers).
cd /opt/openstudio/server && bundle exec rake environment resque:work
