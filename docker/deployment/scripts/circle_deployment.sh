#!/usr/bin/env bash

IMAGETAG=skip
if [ "${CIRCLE_BRANCH}" == "develop" ]; then
    IMAGETAG=develop
elif [ "${CIRCLE_BRANCH}" == "nrcan-master" ]; then
    # NRCAN is still using pre 2.4.1 version of Server. This will break when they upgrade.
    IMAGETAG="$(ruby -e "load 'server/lib/openstudio_server/version.rb'; print OpenstudioServer::VERSION+OpenstudioServer::VERSION_EXT")-nrcan"
elif [ "${CIRCLE_BRANCH}" == "master" ]; then
    # Retrieve the version number from rails
    IMAGETAG="$(ruby -e "load 'server/app/lib/openstudio_server/version.rb'; print OpenstudioServer::VERSION+OpenstudioServer::VERSION_EXT")"
fi

if [ "${IMAGETAG}" != "skip" ] && [ -z ${CI_PULL_REQUEST} ]; then
    # If CI_PULL_REQUEST is set, then the -z returns false (counter-intuitive)

    # Still need email with circleci, presumably because of the version of docker.
    docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS

    echo "Tagging image as $IMAGETAG"
    docker tag nrel/openstudio-server nrel/openstudio-server:$IMAGETAG
    docker tag nrel/openstudio-rserve nrel/openstudio-rserve:$IMAGETAG
    docker push nrel/openstudio-server:$IMAGETAG
    docker push nrel/openstudio-rserve:$IMAGETAG

    if [ "${CIRCLE_BRANCH}" == "master" ]; then
        # Deploy master as the latest.
        docker tag nrel/openstudio-server nrel/openstudio-server:latest
        docker tag nrel/openstudio-rserve nrel/openstudio-rserve:latest

        docker push nrel/openstudio-server:latest
        docker push nrel/openstudio-rserve:latest
    fi

else
    echo "Not on a deployable branch [develop/master] or this is a pull request"
fi
