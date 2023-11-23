#!/usr/bin/env bash

# This script assumes you are running as a superuser.

OPENSTUDIO_VERSION=$1
OPENSTUDIO_SHA=$2
OPENSTUDIO_VERSION_EXT=$3

if [ ! -z ${OPENSTUDIO_VERSION} ] && [ ! -z ${OPENSTUDIO_SHA} ]; then
    # OPENSTUDIO_VERSION_EXT may be empty
    OPENSTUDIO_DOWNLOAD_FILENAME=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}%2B${OPENSTUDIO_SHA}-Ubuntu-20.04-x86_64.deb
    echo "Installing OpenStudio ${OPENSTUDIO_DOWNLOAD_FILENAME}"
    #OPENSTUDIO_DOWNLOAD_BASE_URL=https://openstudio-ci-builds.s3-us-west-2.amazonaws.com/develop
    OPENSTUDIO_DOWNLOAD_BASE_URL=https://github.com/NREL/OpenStudio/releases/download/v3.7.0
    OPENSTUDIO_DOWNLOAD_URL=$OPENSTUDIO_DOWNLOAD_BASE_URL/$OPENSTUDIO_DOWNLOAD_FILENAME

    # copying this from the docker-openstudio dockerfile
    apt-get update && apt-get install -y curl vim gdebi-core libgmp-dev libffi-dev build-essential zlib1g-dev vim git locales sudo
    export $OPENSTUDIO_DOWNLOAD_URL

    echo "OpenStudio Package Download URL is ${OPENSTUDIO_DOWNLOAD_URL}"
    curl -SLO $OPENSTUDIO_DOWNLOAD_URL
    # Verify that the download was successful (not access denied XML from s3)
    grep -v -q "<Code>AccessDenied</Code>" ${OPENSTUDIO_DOWNLOAD_FILENAME}
    gdebi -n $OPENSTUDIO_DOWNLOAD_FILENAME
    # cleanup
    rm -f $OPENSTUDIO_DOWNLOAD_FILENAME
    rm -rf /var/lib/apt/lists/*
    locale-gen en_US en_US.UTF-8
    dpkg-reconfigure locales
    rm $OPENSTUDIO_DOWNLOAD_FILENAME
else
    echo "Must pass in the OpenStudio version, and sha to be installed (e.g. install_openstudio.sh 2.4.0 f58a3e1808)"
    exit 9
fi
