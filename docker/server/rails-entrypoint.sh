#!/bin/bash

echo 'Provisioning data volume osdata'
sleep 1
mkdir -p /mnt/openstudio/server/R && chmod 777 /mnt/openstudio/server/R
mkdir -p /mnt/openstudio/server/assets && chmod 777 /mnt/openstudio/server/assets
mkdir -p /mnt/openstudio/server/assets/variables && chmod 777 /mnt/openstudio/server/assets/variables
mkdir -p /opt/openstudio/server/tmp && chmod 777 /opt/openstudio/server/tmp
mkdir -p /mnt/coredumps/ && chmod 777 /mnt/coredumps/
sleep 1

echo 'Setting permissions on logs'
chmod 775 /opt/openstudio/server/log
chmod 666 /opt/openstudio/server/log/*.log
sleep 1

echo 'Defaulting required variables which are not present'
[ -z "$MAX_REQUESTS" ] && export MAX_REQUESTS=50;
[ -z "$MAX_POOL" ] && export MAX_POOL=16;
sleep 1

echo 'Configuring nginx'
{ rm /opt/nginx/conf/nginx.conf && awk  -v MAX_REQUESTS=$MAX_REQUESTS '{gsub("MAX_REQUESTS_SUB", MAX_REQUESTS, $0); print}' > /opt/nginx/conf/nginx.conf; } < /opt/nginx/conf/nginx.conf
{ rm /opt/nginx/conf/nginx.conf && awk  -v MAX_POOL=$MAX_POOL '{gsub("MAX_POOL_SUB", MAX_POOL, $0); print}' > /opt/nginx/conf/nginx.conf; } < /opt/nginx/conf/nginx.conf
sleep 1

echo 'Beginning CMD boot process.'
umask 0000

exec "$@"
