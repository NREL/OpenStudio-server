#!/usr/bin/env bash

OPENSTUDIO_VERSION=$1
OPENSTUDIO_SHA=$2

if [ ! -z ${OPENSTUDIO_VERSION} ] && [ ! -z ${OPENSTUDIO_SHA} ]; then
    echo "Installing OpenStudio ${OPENSTUDIO_VERSION}.${OPENSTUDIO_SHA}"

    OPENSTUDIO_DOWNLOAD_BASE_URL=https://s3.amazonaws.com/openstudio-builds/$OPENSTUDIO_VERSION
    OPENSTUDIO_DOWNLOAD_FILENAME=OpenStudio-$OPENSTUDIO_VERSION.$OPENSTUDIO_SHA-Linux.deb
    OPENSTUDIO_DOWNLOAD_URL=$OPENSTUDIO_DOWNLOAD_BASE_URL/$OPENSTUDIO_DOWNLOAD_FILENAME

    # Install gdebi, then download and install OpenStudio, then clean up.
    # gdebi handles the installation of OpenStudio's dependencies including Qt5 and Boost
    # libwxgtk3.0-0 is a new dependency as of 3/8/2018
    sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        libboost-thread1.55.0 \
        libwxgtk3.0-0 \
        gdebi-core \
        curl \
        git \
        && curl -SLO --insecure --retry 3 $OPENSTUDIO_DOWNLOAD_URL \
        && sudo gdebi -n $OPENSTUDIO_DOWNLOAD_FILENAME \
        && rm -f $OPENSTUDIO_DOWNLOAD_FILENAME \
        && sudo rm -rf /usr/SketchUpPlugin \
        && sudo rm -rf /var/lib/apt/lists/*
else
    echo "Must pass in the OpenStudio version and sha to be installed (e.g. install_openstudio.sh 2.4.0 f58a3e1808)"
    exit 9
fi