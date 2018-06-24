#!/bin/bash -x

echo "The build architecture is ${TRAVIS_OS_NAME}"

if [ "${BUILD_TYPE}" == "docker" ]; then
    echo "Installing docker compose"
    sudo rm /usr/local/bin/docker-compose
    curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > docker-compose
    chmod +x docker-compose
    sudo mv docker-compose /usr/local/bin

    # install pipeviewer
    sudo apt-get install -y pv
else
    if [ "${TRAVIS_OS_NAME}" == "osx" ]; then
        brew update > /Users/travis/build/NREL/OpenStudio-server/spec/files/logs/brew-update.log
    #    AP: do we need mongo install here ? seems to be handled by service defined in travis yml
        brew install mongodb@3.4 pv tree
        ln -s /usr/local/opt/mongodb@3.4/bin/* /usr/local/bin
        unset BUNDLE_GEMFILE

        curl -SLO --insecure https://s3.amazonaws.com/openstudio-builds/$OPENSTUDIO_VERSION/OpenStudio-$OPENSTUDIO_VERSION.$OPENSTUDIO_VERSION_SHA-Darwin.zip
        unzip OpenStudio-$OPENSTUDIO_VERSION.$OPENSTUDIO_VERSION_SHA-Darwin.zip
        # Use the install script that is in this repo now, the one on OpenStudio/develop has changed
        sed -i -e "s|REPLACEME|$HOME/openstudio|" ci/travis/install-mac.qs
        rm -rf $HOME/openstudio
        # Will install into $HOME/openstudio and RUBYLIB will be $HOME/openstudio/Ruby
        sudo ./OpenStudio-$OPENSTUDIO_VERSION.$OPENSTUDIO_VERSION_SHA-Darwin.app/Contents/MacOS/OpenStudio-$OPENSTUDIO_VERSION.$OPENSTUDIO_VERSION_SHA-Darwin --script ci/travis/install-mac.qs
        tree ${HOME}/openstudio/Ruby
    #    mongo_dir="/usr/local/bin"
    elif [ "${TRAVIS_OS_NAME}" == "linux" ]; then
        echo "Setting up Ubuntu for unit tests and Rubocop"
        # install pipe viewer to throttle printing logs to screen (not a big deal in linux, but it is in osx)
        sudo apt-get install -y pv
        mkdir -p reports/rspec
        ./docker/deployment/scripts/install_openstudio.sh $OPENSTUDIO_VERSION $OPENSTUDIO_VERSION_SHA
    fi

    ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" install_gems --with_test_develop --debug --verbose --use_cached_gems

    # create dir for output files which will be generated in case of failure
    mkdir "${TRAVIS_BUILD_DIR}/spec/unit-test"
fi

