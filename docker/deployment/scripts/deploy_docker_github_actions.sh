#!/usr/bin/env bash

# Default set IMAGETAG to skip. 
IMAGETAG="skip"

if [ "${GITHUB_REF}" == "refs/heads/develop" ]; then
    IMAGETAG="develop"
elif [ "${GITHUB_REF}" == "refs/heads/2.9.X-LTS" ]; then
    IMAGETAG="2.9.X-LTS"
elif [ "${GITHUB_REF}" == "refs/heads/master" ]; then
    # Retrieve the version number from rails
    IMAGETAG="$(ruby -e "load 'server/app/lib/openstudio_server/version.rb'; print OpenstudioServer::VERSION+OpenstudioServer::VERSION_EXT")"
# Uncomment and set branch name for custom builds. 
# Currently setting this to setup_github_actions to test upload. 
elif [ "${GITHUB_REF}" == "refs/heads/setup_github_actions" ]; then
    IMAGETAG=experimental
#elif [ "${GITHUB_REF}" == "refs/heads/3.6.1-4" ]; then
#     IMAGETAG="3.6.1-4"
fi

if [ "${IMAGETAG}" != "skip" ]; then
    echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

    echo "Tagging image as $IMAGETAG"
    docker tag nrel/openstudio-server nrel/openstudio-server:$IMAGETAG; (( exit_status = exit_status || $? ))
    docker tag nrel/openstudio-rserve nrel/openstudio-rserve:$IMAGETAG; (( exit_status = exit_status || $? ))
    docker push nrel/openstudio-server:$IMAGETAG; (( exit_status = exit_status || $? ))
    docker push nrel/openstudio-rserve:$IMAGETAG; (( exit_status = exit_status || $? ))

    if [ "${GITHUB_REF}" == "refs/heads/master" ]; then
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
