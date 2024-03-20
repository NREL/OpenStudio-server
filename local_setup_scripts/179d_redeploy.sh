#!/bin/bash

num_vol=$(docker volume ls -q | wc -l)
echo "number of volumes: $num_vol"

num_ser=$(docker service ls -q | wc -l)
echo "number of services: $num_ser"

echo "removing services that use volume osdata first"
docker service rm osserver_web osserver_web-background osserver_rserve

echo "removing mongo service"
docker service rm osserver_db

echo "Removing the osserver stack"
if ! docker stack rm osserver; then
    echo "nothing in osserver stack, continuing..."
fi

# Loop until only the registry service is active
while true; do
    # Get the list of running services excluding the registry
    services=$(docker service ls --filter name=osserver --format "{{.Name}}" | grep -v "registry")

    # Check if the services list is empty
    if [ -z "$services" ]; then
        echo "Only registry service is active now."
        break
    else
        echo "Waiting for services to stop. Active services:"
        echo "$services"
    fi

    sleep 5
done

echo "sleeping for 5"
sleep 5

echo "removing and creating /media/data/dbdata"
rm -rf /media/data/dbdata
mkdir /media/data/dbdata && chmod 777 /media/data/dbdata

echo "removing and creating /media/data/dbdata"
rm -rf /media/data/dbdata
mkdir /media/data/dbdata && chmod 777 /media/data/dbdata

# Verify that the directory is empty
if [ "$(ls -A /media/data/dbdata)" ]; then
    echo "Directory is not empty!"
else
    echo "Directory is empty."
fi

echo "Attempting to remove osdata volume..."
while true; do
    if docker volume rm -f osdata 2>/dev/null; then
        echo "Successfully removed osdata volume."
        break
    else
        echo "osdata volume is still in use, retrying..."
        sleep 5
    fi
done

echo "deploying stack"
docker stack deploy osserver --compose-file=docker-compose.yml
while ( nc -zv 127.0.0.1 80 3>&1 1>&2- 2>&3- ) | awk -F ":" '$3 != " Connection refused" {exit 1}'; do sleep 5; done

echo "scaling workers"
docker service scale osserver_worker=106
echo 'osserver stack redeployed'

num_ser=$(docker service ls -q | wc -l)
echo "number of services(should be 7): $num_ser"

echo "waiting for volumes to reach 218"
while true; do
    current_vol=$(docker volume ls -q | wc -l)
    echo "Current number of volumes: $current_vol"

    if [ "$current_vol" -eq 218 ]; then
        echo "Reached 218 volumes"
        break
    fi

    sleep 5
done

echo 'osserver stack fully redeployed and volumes are ready'
