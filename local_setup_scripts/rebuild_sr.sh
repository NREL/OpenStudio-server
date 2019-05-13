#!/bin/bash -e
cd /home/ubuntu/Projects/OpenStudio-Server/
docker stack rm osserver || true

docker volume rm osdata || true
docker volume rm dbdata || true

while [ $(docker ps -q | wc -l) != 1 ]; do sleep 5; done
echo "server rebuild"
docker image rm 127.0.0.1:5000/openstudio-server -f || true
docker build . -t="127.0.0.1:5000/openstudio-server"
docker push 127.0.0.1:5000/openstudio-server
echo "rserve rebuild"
cd /home/ubuntu/Projects/OpenStudio-Server/docker/R/
docker image rm 127.0.0.1:5000/openstudio-rserve -f || true
docker build . -t="127.0.0.1:5000/openstudio-rserve"
docker push 127.0.0.1:5000/openstudio-rserve
echo "jupyter rebuild"
cd /home/ubuntu/Projects/docker-openstudio-jupyter
docker image rm 127.0.0.1:5000/openstudio-jupyter -f || true
docker build . -t="127.0.0.1:5000/openstudio-jupyter"
docker push 127.0.0.1:5000/openstudio-jupyter
echo "rnotebook rebuild"
cd /home/ubuntu/Projects/docker-openstudio-rnotebook
docker image rm 127.0.0.1:5000/openstudio-rnotebook -f || true
docker build . -t="127.0.0.1:5000/openstudio-rnotebook"
docker push 127.0.0.1:5000/openstudio-rnotebook
echo "pull mongo"
docker pull mongo:3.4.10
docker tag mongo 127.0.0.1:5000/mongo
docker push 127.0.0.1:5000/mongo
docker image rm mongo:3.4.10 -f || true
echo "pull redis"
docker pull redis:4.0.6
docker tag redis:4.0.6 127.0.0.1:5000/redis
docker push 127.0.0.1:5000/redis
docker image rm redis -f || true
cd /home/ubuntu/
docker stack deploy osserver --compose-file=/home/ubuntu/Projects/OpenStudio-Server/local_setup_scripts/docker-compose.yml
while ( nc -zv 127.0.0.1 80 3>&1 1>&2- 2>&3- ) | awk -F ":" '$3 != " Connection refused" {exit 1}'; do sleep 5; done
docker service scale osserver_worker=42
echo 'osserver stack rebuilt and redeployed'

