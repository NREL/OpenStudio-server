#!/usr/bin/env bash -e
cd /C/Projects/OS-Server-fmu
docker stack rm osserver -f || true

docker volume rm osdata -f || true
docker volume rm dbdata -f || true

while [ $(docker ps -q | wc -l) != 1 ]; do sleep 5; done
docker image rm 127.0.0.1:5000/openstudio-server -f
docker build . -t="127.0.0.1:5000/openstudio-server"
docker push 127.0.0.1:5000/openstudio-server
cd /C/Projects/OS-Server-fmu/docker/R
docker image rm 127.0.0.1:5000/openstudio-rserve -f
docker build . -t="127.0.0.1:5000/openstudio-rserve"
docker push 127.0.0.1:5000/openstudio-rserve
docker pull mongo:3.4.10
docker tag mongo:3.4.10 127.0.0.1:5000/mongo
docker push 127.0.0.1:5000/mongo
#docker image rm mongo || true
docker pull redis:4.0.6
docker tag redis:4.0.6 127.0.0.1:5000/redis
docker push 127.0.0.1:5000/redis
cd /C/Projects/OS-Server-fmu/local_setup_scripts/win64
docker stack deploy osserver --compose-file=docker-compose.yml
while ( nc -zv 127.0.0.1 80 3>&1 1>&2- 2>&3- ) | awk -F ":" '$3 != " Connection refused" {exit 1}'; do sleep 5; done
docker service scale osserver_worker=1
echo 'osserver stack rebuilt and redeployed'

