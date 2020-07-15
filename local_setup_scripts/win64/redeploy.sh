#!/bin/bash -e
docker stack rm osserver || true
while [ $(docker ps -q | wc -l) != 1 ]; do sleep 5; done
sleep 10
echo 'docker volume rm osdata and dbdata'
docker volume rm -f osdata || true
docker volume rm -f dbdata || true
docker stack deploy osserver --compose-file=docker-compose.yml
while ( nc -zv 127.0.0.1 80 3>&1 1>&2- 2>&3- ) | awk -F ":" '$3 != " Connection refused" {exit 1}'; do sleep 5; done
docker service scale osserver_worker=1
echo 'osserver stack redeployed'

