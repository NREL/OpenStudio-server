#!/bin/bash

echo 'Provisioning data volume osdata'
mkdir -p /mnt/openstudio/log && chmod 775 /mnt/openstudio/log
echo 'Beginning CMD boot process.'

exec "$@"
