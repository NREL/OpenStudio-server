#!/usr/bin/pwsh
echo "full redploy with OS version: $1"

docker stack rm osserver
docker service rm $(docker service ls -q)
docker swarm leave -f
echo "docker rm ps"
docker rm -f $(docker ps -aq)
echo "docker volume rm"
docker volume rm $(docker volume ls -q)
echo "docker image rm"
docker image rm -f $(docker image ls -aq)

echo "pull images"
docker pull registry:2.6
docker pull nrel/openstudio-server:$Args
docker pull nrel/openstudio-rserve:$Args
docker pull mongo:6.0.7
docker pull redis:4.0.6

echo "create registry"
docker volume create --name=regdata
docker swarm init
docker service create --name registry --publish 5000:5000 --mount type=volume,source=regdata,destination=/C/Projects/OS-Server-develop/local_setup_scripts/Win64 registry:2.6
sleep 10
echo "tag"
docker tag nrel/openstudio-server:$Args 127.0.0.1:5000/openstudio-server
docker tag nrel/openstudio-rserve:$Args 127.0.0.1:5000/openstudio-rserve
docker tag mongo:6.0.7 127.0.0.1:5000/mongo
docker tag redis:4.0.6 127.0.0.1:5000/redis
sleep 3
echo "push"
docker push 127.0.0.1:5000/openstudio-server
docker push 127.0.0.1:5000/openstudio-rserve
docker push 127.0.0.1:5000/mongo
docker push 127.0.0.1:5000/redis

echo "deploy"
#docker stack deploy osserver --compose-file=C:/Projects/OS-Server/local_setup_scripts/docker-compose.yml
docker stack deploy osserver --compose-file=docker-compose.yml

docker service scale osserver_worker=4
echo 'osserver stack redeployed'

