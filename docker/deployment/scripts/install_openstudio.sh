#!/usr/bin/env bash

# This script assumes you are running as a superuser.

OPENSTUDIO_VERSION=$1
OPENSTUDIO_SHA=$2
OPENSTUDIO_VERSION_EXT=$3

if [ ! -z ${OPENSTUDIO_VERSION} ] && [ ! -z ${OPENSTUDIO_SHA} ]; then
    # OPENSTUDIO_VERSION_EXT may be empty
    OPENSTUDIO_DOWNLOAD_FILENAME=OpenStudio-$OPENSTUDIO_VERSION.$OPENSTUDIO_SHA-Linux.deb
    
    echo "Installing OpenStudio ${OPENSTUDIO_DOWNLOAD_FILENAME}"

    OPENSTUDIO_DOWNLOAD_BASE_URL=https://s3.amazonaws.com/openstudio-builds/$OPENSTUDIO_VERSION
    OPENSTUDIO_DOWNLOAD_URL=$OPENSTUDIO_DOWNLOAD_BASE_URL/$OPENSTUDIO_DOWNLOAD_FILENAME

    # Install gdebi, then download and install OpenStudio, then clean up.
    # gdebi handles the installation of OpenStudio's dependencies including Qt5 and Boost
    # libwxgtk3.0-0 is a new dependency as of 3/8/2018
    apt-get update && apt-get install -y --no-install-recommends \
        libwxgtk3.0-0v5 \
        gdebi-core \
        locales \
        curl \
        git \
        && curl -SLO --insecure --retry 3 $OPENSTUDIO_DOWNLOAD_URL \
        && gdebi -n $OPENSTUDIO_DOWNLOAD_FILENAME \
        && rm -f $OPENSTUDIO_DOWNLOAD_FILENAME \
        && rm -rf /usr/SketchUpPlugin \
        && rm -rf /var/lib/apt/lists/*
else
    echo "Must pass in the OpenStudio version, and sha to be installed (e.g. install_openstudio.sh 2.4.0 f58a3e1808)"
    exit 9
fi