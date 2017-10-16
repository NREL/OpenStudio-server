#!/bin/bash

echo 'Provisioning data volume osdata'
mkdir -p /mnt/openstudio/log && chmod 775 /mnt/openstudio/log
mkdir -p /mnt/coredumps/ && chmod 777 /mnt/coredumps/
echo 'Beginning CMD boot process.'

exec "$@"
