#!/bin/bash -x

echo "The build architecture is ${TRAVIS_OS_NAME}"

if [ "${BUILD_TYPE}" == "docker" ]; then
    echo "Installing docker compose"
    sudo rm /usr/local/bin/docker-compose
    curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > docker-compose
    chmod +x docker-compose
    sudo mv docker-compose /usr/local/bin
    # install pipeviewer
    sudo apt-get update
    sudo apt-get install -y pv

else
    if [ "${TRAVIS_OS_NAME}" == "osx" ]; then

        brew update > /Users/travis/build/NREL/OpenStudio-server/spec/files/logs/brew-update.log
        # AP: do we need mongo install here ? seems to be handled by service defined in travis yml.
        # NL: Services are not handled in osx
        brew install pv tree ruby@2.5

        # Install mongodb from a download. Brew is hanging and requires building mongo. This also speeds up the builds.
        curl -SLO https://fastdl.mongodb.org/osx/mongodb-osx-ssl-x86_64-3.4.18.tgz
        tar xvzf mongodb-osx-ssl-x86_64-3.4.18.tgz
        cp mongodb-osx-x86_64-3.4.18/bin/* /usr/local/bin/

        # Install openstudio -- Use the install script that is in this repo now, the one on OpenStudio/develop has changed
        curl -SLO --insecure https://openstudio-ci-builds.s3-us-west-2.amazonaws.com/develop/OpenStudio-3.0.0-beta%2Bc1e87e9d3b-Darwin.dmg
        hdiutil attach OpenStudio-3.0.0-beta+c1e87e9d3b-Darwin.dmg
        sed -i -e "s|REPLACEME|$HOME/openstudio|" ci/travis/install-mac.qs
        rm -rf $HOME/openstudio
        # Will install into $HOME/openstudio and RUBYLIB will be $HOME/openstudio/Ruby
        sudo /Volumes/OpenStudio-3.0.0-beta+c1e87e9d3b-Darwin.dmg/OpenStudio-3.0.0-beta+c1e87e9d3b-Darwin.app/Contents/MacOS/OpenStudio-3.0.0-beta+c1e87e9d3b-Darwin --script ci/travis/install-mac.qs
        hdiutil detach /Volumes/OpenStudio-3.0.0-beta+c1e87e9d3b-Darwin -force

        export PATH="$TRAVIS_BUILD_DIR/gems/bin:/usr/local/opt/ruby@2.5/bin:$HOME/openstudio/bin:$PATH"
        export RUBYLIB="$HOME/openstudio/Ruby"
        export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
        export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"

    elif [ "${TRAVIS_OS_NAME}" == "linux" ]; then
        echo "Setting up Ubuntu for unit tests and Rubocop"
        # install pipe viewer to throttle printing logs to screen (not a big deal in linux, but it is in osx)
        sudo apt-get update
        # per travis docs, mongodb and redis should already be installed and started from services key in bionic, but this isn't working.  explicitly install.
        #sudo apt-get install -y pv tree ruby2.5 mongodb redis-server
        sudo apt-get install redis-server || true
        sudo systemctl stop redis-server.service
        sudo sed -e 's/^bind.*/bind 127.0.0.1/' /etc/redis/redis.conf > redis.conf
        sudo mv redis.conf /etc/redis/redis.conf
        cat /etc/redis/redis.conf
        sudo systemctl start redis-server.service || true
        sudo systemctl status redis-server.service
        sudo apt-get install -y pv tree mongodb ruby2.5
        sudo systemctl start mongodb

        mkdir -p reports/rspec
        # AP: this appears to only be used for Travis/Linux so we should move it out of the docker/deployment/scripts dir
        sudo ./ci/travis/install_openstudio.sh $OPENSTUDIO_VERSION $OPENSTUDIO_VERSION_SHA $OPENSTUDIO_VERSION_EXT
        export RUBYLIB=/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/Ruby
        export ENERGYPLUS_EXE_PATH=/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/EnergyPlus/energyplus
        export PATH=/usr/bin:/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/bin:${PATH}
        export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
        export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
    fi
    echo "verifying os installation"
    unset BUNDLE_GEMFILE && openstudio openstudio_version

    cd ${TRAVIS_BUILD_DIR}/server
    printenv
    ruby -v
    ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" install_gems --with_test_develop --debug --verbose --use_cached_gems
    bundle -v
    # create dir for output files which will be generated in case of failure
    mkdir "${TRAVIS_BUILD_DIR}/spec/unit-test"

fi
