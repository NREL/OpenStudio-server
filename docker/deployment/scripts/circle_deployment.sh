#!/bin/bash -x

IMAGETAG=skip
if [ "${CIRCLE_BRANCH}" == "develop" ]; then
    IMAGETAG=develop
elif [ "${CIRCLE_BRANCH}" == "master" ]; then
    # Retrieve the version number from rails
    IMAGETAG="$(ruby -e "load 'server/lib/openstudio_server/version.rb'; print OpenstudioServer::VERSION+OpenstudioServer::VERSION_EXT")"
fi

if [ "${IMAGETAG}" != "skip" ] && [ -z ${CI_PULL_REQUEST} ]; then
    # If CI_PULL_REQUEST is set, then the -z returns false (counter-intuitive)
    docker-compose build --pull
    docker login -u $DOCKER_USER -p $DOCKER_PASS

    echo "Tagging image as $IMAGETAG"
    docker tag nrel/openstudio-server nrel/openstudio-server:$IMAGETAG
    docker tag nrel/openstudio-rserve nrel/openstudio-rserve:$IMAGETAG
    docker push nrel/openstudio-server:$IMAGETAG
    docker push nrel/openstudio-rserve:$IMAGETAG
else
    echo "Not on a deployable branch [develop/master] or this is a pull request"
fi
