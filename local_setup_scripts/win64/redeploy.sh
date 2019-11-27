#!/usr/bin/env bash -e
cd /C/Projects/OS-Server-fmu/
docker stack rm osserver -f || true
while [ $(docker ps -q | wc -l) != 1 ]; do sleep 5; done
sleep 10
echo 'docker volume rm osdata and dbdata'
docker volume rm osdata -f || true
docker volume rm dbdata -f || true
docker stack deploy osserver --compose-file=/C/Projects/OS-Server-fmu/local_setup_scripts/win64/docker-compose.yml
while ( nc -zv 127.0.0.1 80 3>&1 1>&2- 2>&3- ) | awk -F ":" '$3 != " Connection refused" {exit 1}'; do sleep 5; done
docker service scale osserver_worker=1
echo 'osserver stack redeployed'

