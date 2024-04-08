#!/usr/bin/env bash

echo "Waiting for Mongo to start"
/usr/local/bin/wait-for-it --strict -t 0 db:27017

echo "Waiting for Redis to start"
/usr/local/bin/wait-for-it --strict -t 0 queue:6379

# Ensure the log directory exists
mkdir -p /opt/openstudio/server/log

# Start aws_imdsv2_polling script and redirect output to log file
/opt/openstudio/server/bin/aws_imdsv2 >> /opt/openstudio/server/log/aws_imds.log 2>&1 &

# Only start a single worker when calling this script (do not use resque:workers).
cd /opt/openstudio/server && bundle exec rake environment resque:work
