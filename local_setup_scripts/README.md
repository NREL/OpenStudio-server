# Local Setup Scripts

These are useful scripts which are used to setup local deployments are described below:

* *rebuild_sr.sh*: This script will rebuild the docker containers using the code in this repo and deploy the swarm.
* *redploy.sh*: This script will redploy an existing docker swarm.
* *nuke.sh*: This script is useful for deleting all docker images and reinstalling a fresh deployment from published containers on dockerhub.  It takes as an argument the tag for the containers to install.
* *docker_logs.sh*: This script is useful for getting the docker logs from the swarm containers.

The win64 directory contains windows version of these files for setting up a deployment on windows using Docker Desktop.