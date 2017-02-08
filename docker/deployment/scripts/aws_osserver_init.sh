#!/bin/bash

echo ""
echo "------------------------------------------------------------------------"
echo "Pulling nrel/openstudio-server:$OSSERVER_DOCKERHUB_TAG from DockerHub"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker pull nrel/openstudio-server:$OSSERVER_DOCKERHUB_TAG
echo "export OSSERVER_DOCKERHUB_TAG=$OSSERVER_DOCKERHUB_TAG" >> /home/ubuntu/.bashrc
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Pulling nrel/openstudio-rserve:$OSSERVER_DOCKERHUB_TAG from DockerHub"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker pull nrel/openstudio-rserve:$OSSERVER_DOCKERHUB_TAG
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Pulling mongo from DockerHub"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker pull mongo
sleep 1

echo ""
echo "------------------------------------------------------------------------"
echo "Creating the osdata data container volume"
echo "------------------------------------------------------------------------"
echo ""
sleep 1
docker volume create --name=osdata
sleep 1
