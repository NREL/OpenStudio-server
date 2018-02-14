#!/bin/bash -x

echo "The build architecture is ${BUILD_ARCH}"
if [ "${BUILD_ARCH}" == "OSX" ]; then
    mkdir /Users/travis/build/NREL/OpenStudio-server/spec/files/logs
    brew update > /Users/travis/build/NREL/OpenStudio-server/spec/files/logs/brew-update.log
    brew install mongodb@3.4
    ln -s /usr/local/opt/mongodb@3.4/bin/* /usr/local/bin
    unset BUNDLE_GEMFILE

    OPENSTUDIO_VERSION=2.4.0
    OPENSTUDIO_SHA=f58a3e1808
    OPENSTUDIO_DOWNLOAD_BASE_URL=https://s3.amazonaws.com/openstudio-builds/$OPENSTUDIO_VERSION
    OPENSTUDIO_DOWNLOAD_FILENAME=OpenStudio-$OPENSTUDIO_VERSION.$OPENSTUDIO_SHA-Darwin.zip
    OPENSTUDIO_DOWNLOAD_URL=$OPENSTUDIO_DOWNLOAD_BASE_URL/$OPENSTUDIO_DOWNLOAD_FILENAME

    curl -SLO ${OPENSTUDIO_DOWNLOAD_URL}
    mkdir ~/openstudio
    mkdir ~/to_rm
    unzip ${OPENSTUDIO_DOWNLOAD_FILENAME} -d ~/to_rm
    mv ~/to_rm/OpenStudio-$OPENSTUDIO_VERSION.$OPENSTUDIO_SHA-Darwin.app/Contents/Resources/Ruby ~/openstudio/
    rm -rf ~/to_rm
    export RUBYLIB="${HOME}/openstudio/:$RUBYLIB"
    ruby ./bin/openstudio_meta install_gems --with_test_develop --debug --verbose --use_cached_gems
elif [ "${BUILD_ARCH}" == "Ubuntu" ]; then
    echo "Setting up Ubuntu for unit tests and Rubocop"
    mkdir -p reports/rspec

    # If not running on travis, then to install MongoDB and Ruby, run the following:
#    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
#    echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list
#    sudo apt-get update
#    sudo mkdir -p /data/db
#    sudo apt-get install -y mongodb-org
#    ./docker/deployment/scripts/install_ruby.sh 2.2.4 b6eff568b48e0fda76e5a36333175df049b204e91217aa32a65153cc0cdcb761

    ./docker/deployment/scripts/install_openstudio.sh 2.4.0 f58a3e1808
    export RUBYLIB="/usr/Ruby:$RUBYLIB"
    if [ "${BUILD_TYPE}" == "test" ]; then
        echo "In test mode"
        BUNDLE_GEMFILE=./server/Gemfile bundle install --with=test develop
    elif [ "${BUILD_TYPE}" == "integration" ]; then
        # If we are running integration tests, then we need to get the openstudio_meta install_gems working
        ruby ./bin/openstudio_meta install_gems --with_test_develop --debug --verbose --use_cached_gems
    fi
elif [ "${BUILD_ARCH}" == "RedHat" ]; then
	docker pull nrel/openstudio-server-hpc
	CONTAINER_ID=$(mktemp)
	docker run --detach --volume="${PWD}":/root/openstudio-server ${RUN_OPTS} nrel/openstudio-server-hpc "/usr/lib/systemd/systemd" > "${CONTAINER_ID}"
	docker exec --tty "$(cat ${CONTAINER_ID})" env TERM=xterm ruby ~/openstudio-server/bin/openstudio_meta install_gems --with_test_develop --debug --verbose
fi
