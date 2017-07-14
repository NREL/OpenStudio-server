#!/bin/bash

echo 'Provisioning data volume osdata'
mkdir -p /mnt/openstudio/server/R && chmod 777 /mnt/openstudio/server/R
mkdir -p /mnt/openstudio/server/assets && chmod 777 /mnt/openstudio/server/assets
mkdir -p /mnt/openstudio/server/assets/variables && chmod 777 /mnt/openstudio/server/assets/variables
mkdir -p /opt/openstudio/server/tmp && chmod 777 /opt/openstudio/server/tmp
mkdir -p /tmp/coredumps/ && chmod 777 /tmp/coredumps/
echo 'Beginning CMD boot process.'
umask 0000

exec "$@"
