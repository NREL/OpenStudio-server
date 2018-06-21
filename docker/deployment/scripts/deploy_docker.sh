#!/usr/bin/env bash

IMAGETAG=skip
if [ "${TRAVIS_BRANCH}" == "develop" ]; then
    IMAGETAG=develop
elif [ "${TRAVIS_BRANCH}" == "nrcan-master" ]; then
    # NRCAN is still using pre 2.4.1 version of Server. This will break when they upgrade.
    IMAGETAG="$(ruby -e "load 'server/lib/openstudio_server/version.rb'; print OpenstudioServer::VERSION+OpenstudioServer::VERSION_EXT")-nrcan"
elif [ "${TRAVIS_BRANCH}" == "master" ]; then
    # Retrieve the version number from rails
    IMAGETAG="$(ruby -e "load 'server/app/lib/openstudio_server/version.rb'; print OpenstudioServer::VERSION+OpenstudioServer::VERSION_EXT")"
elif [ "${TRAVIS_BRANCH}" == "experimental" ]; then
    IMAGETAG=experimental
fi

if [ "${IMAGETAG}" != "skip" ] && [ "${TRAVIS_PULL_REQUEST}" == "false" ]; then
    echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

    echo "Tagging image as $IMAGETAG"
    docker tag nrel/openstudio-server nrel/openstudio-server:$IMAGETAG; (( exit_status = exit_status || $? ))
    docker tag nrel/openstudio-rserve nrel/openstudio-rserve:$IMAGETAG; (( exit_status = exit_status || $? ))
    docker push nrel/openstudio-server:$IMAGETAG; (( exit_status = exit_status || $? ))
    docker push nrel/openstudio-rserve:$IMAGETAG; (( exit_status = exit_status || $? ))

    if [ "${TRAVIS_BRANCH}" == "master" ]; then
        # Deploy master as the latest.
        docker tag nrel/openstudio-server nrel/openstudio-server:latest; (( exit_status = exit_status || $? ))
        docker tag nrel/openstudio-rserve nrel/openstudio-rserve:latest; (( exit_status = exit_status || $? ))

        docker push nrel/openstudio-server:latest; (( exit_status = exit_status || $? ))
        docker push nrel/openstudio-rserve:latest; (( exit_status = exit_status || $? ))
    fi

    exit $exit_status
else
    echo "Not on a deployable branch [master/nrcan-master/develop] or this is a pull request"
fi
