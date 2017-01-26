#!/bin/bash

echo ""
echo "------------------------------------------------------------------------"
echo "Pulling nrel/openstudio-server:$OSSERVER_DOCKERHUB_TAG from DockerHub"
echo "------------------------------------------------------------------------"
echo ""
docker pull nrel/openstudio-server:$OSSERVER_DOCKERHUB_TAG
echo "export OSSERVER_DOCKERHUB_TAG=$OSSERVER_DOCKERHUB_TAG" >> /home/ubuntu/.bashrc

echo ""
echo "------------------------------------------------------------------------"
echo "Pulling nrel/openstudio-rserve:$OSSERVER_DOCKERHUB_TAG from DockerHub"
echo "------------------------------------------------------------------------"
echo ""
docker pull nrel/openstudio-rserve:$OSSERVER_DOCKERHUB_TAG

echo ""
echo "------------------------------------------------------------------------"
echo "Pulling mongo from DockerHub"
echo "------------------------------------------------------------------------"
echo ""
docker pull mongo

echo ""
echo "------------------------------------------------------------------------"
echo "Creating the osdata data container volume"
echo "------------------------------------------------------------------------"
echo ""
docker volume create --name=osdata
