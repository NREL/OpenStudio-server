#!/bin/bash

echo 'Provisioning data volume osdata'
mkdir -p /mnt/openstudio/log && chmod 775 /mnt/openstudio/log
mkdir -p /tmp/coredumps/ && chmod 777 /tmp/coredumps/
echo 'Beginning CMD boot process.'

exec "$@"
