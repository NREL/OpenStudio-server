#!/bin/bash -e
MONGO_VERSION=3.4.10
REDIS_VERSION=4.0.6
echo ""
echo "------------------------------------------------------------------------"
echo "Creating data volume regdata to persist registry data for provision"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
internalip=$(ip route get 8.8.8.8 | awk '{print $NF; exit}')
docker swarm init --advertise-addr=$internalip
docker pull registry:2.6
docker volume create --name=regdata
docker service create --name registry --publish 5000:5000 --mount type=volume,source=regdata,destination=/var/lib/registry registry:2.6
while ( nc -zv $internalip 5000 3>&1 1>&2- 2>&3- ) | awk -F ":" '$3 != " Connection refused" {exit 1}'; do sleep 5; done
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Pulling nrel/openstudio-server:$OSSERVER_DOCKERHUB_TAG from DockerHub"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker pull hhorsey/openstudio-server:$OSSERVER_DOCKERHUB_TAG
echo "export OSSERVER_DOCKERHUB_TAG=$OSSERVER_DOCKERHUB_TAG" >> /home/ubuntu/.bashrc
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Pulling nrel/openstudio-rserve:$OSSERVER_DOCKERHUB_TAG from DockerHub"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker pull hhorsey/openstudio-rserve:$OSSERVER_DOCKERHUB_TAG
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Pulling mongo from DockerHub"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker pull mongo:$MONGO_VERSION
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Pulling redis from DockerHub"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker pull redis:$REDIS_VERSION
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Pushing pulled images to registry for persistence and stopping the swarm"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker tag hhorsey/openstudio-server:$OSSERVER_DOCKERHUB_TAG localhost:5000/openstudio-server
docker push localhost:5000/openstudio-server
docker tag hhorsey/openstudio-rserve:$OSSERVER_DOCKERHUB_TAG localhost:5000/openstudio-rserve
docker push localhost:5000/openstudio-rserve
docker tag mongo:$MONGO_VERSION localhost:5000/mongo:latest
docker push localhost:5000/mongo:latest
docker tag redis:$REDIS_VERSION localhost:5000/redis:latest
docker push localhost:5000/redis:latest
docker service rm registry
docker swarm leave -f
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Creating the osdata and dbdata data container volumes"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker volume create --name=osdata
docker volume create --name=dbdata
sleep 1
