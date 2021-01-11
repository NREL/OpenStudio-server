#!/bin/bash -x

echo "The build architecture is ${ImageOS}"

if [ "${ImageOS}" == "docker" ]; then
    echo "Installing docker compose"
    sudo rm /usr/local/bin/docker-compose
    curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > docker-compose
    chmod +x docker-compose
    sudo mv docker-compose /usr/local/bin
    # install pipeviewer
    sudo apt-get update
    sudo apt-get install -y pv

else
    sudo rvm implode --force  # rvm PATH rewriting interferes with portable Ruby.
    if [ "${ImageOS}" == "osx" ]; then

        brew update > /Users/travis/build/NREL/OpenStudio-server/spec/files/logs/brew-update.log
        brew install pv tree
        
        # install portable ruby - required for build that will eventually be published
        # see https://github.com/NREL/OpenStudio-PAT/wiki/Pat-Build-Notes
        curl -SLO --insecure https://openstudio-resources.s3.amazonaws.com/pat-dependencies3/ruby-2.5.5-darwin.tar.gz
        tar xvzf ruby-2.5.5-darwin.tar.gz       
        sudo mv ruby /usr/local/
        otool -L /usr/local/ruby/bin/ruby
        rm ruby-2.5.5-darwin.tar.gz

        # Install mongodb from a download. Brew is hanging and requires building mongo. This also speeds up the builds.
        curl -SLO https://fastdl.mongodb.org/osx/mongodb-macos-x86_64-4.4.2.tgz
        tar xvzf mongodb-macos-x86_64-4.4.2.tgz
        cp mongodb-macos-x86_64-4.4.2/bin/* /usr/local/bin/
        rm -r mongodb-osx*
        
        # Install openstudio -- Use the install script that is in this repo now, the one on OpenStudio/develop has changed
        export OS_NAME=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}%2B${OPENSTUDIO_VERSION_SHA}-Darwin
        export OS_NAME_WITH_PLUS=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-Darwin
        curl -SLO --insecure https://openstudio-builds.s3.amazonaws.com/${OPENSTUDIO_VERSION}/${OS_NAME}.dmg
        # OSX downloads with %2B but installs with + sign. These are the encoded chars in url strings.
        hdiutil attach ${OS_NAME}.dmg
        sed -i -e "s|REPLACEME|$HOME/openstudio|" ci/github-actions/install-mac.qs
        rm -rf $HOME/openstudio
        # Will install into $HOME/openstudio and RUBYLIB will be $HOME/openstudio/Ruby
        sudo /Volumes/${OS_NAME_WITH_PLUS}/${OS_NAME_WITH_PLUS}.app/Contents/MacOS/${OS_NAME_WITH_PLUS} --script ci/travis/install-mac.qs
        hdiutil detach /Volumes/${OS_NAME_WITH_PLUS} -force
        rm ${OS_NAME}.dmg
        export PATH="/usr/local/ruby/bin:$GITHUB_WORKSPACE/gems/bin:$HOME/openstudio/bin:$PATH"
        export RUBYLIB="$HOME/openstudio/Ruby"
        export GEM_HOME="$GITHUB_WORKSPACE/gems"
        export GEM_PATH="$GITHUB_WORKSPACE/gems:$GITHUB_WORKSPACE/gems/bundler/gems"

        # set the ulimit to be higher
        ulimit -a
        ulimit -n 4096
        ulimit -a

    elif [ "${ImageOS}" == "ubuntu18" ]; then
        echo "Setting up Ubuntu for unit tests and Rubocop"
        # install pipe viewer to throttle printing logs to screen (not a big deal in linux, but it is in osx)
        sudo apt-get update && sudo apt-get install -y wget gnupg software-properties-common build-essential
        sudo wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
        echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.4 multiverse | tee /etc/apt/sources.list.d/mongodb-org-4.4.list"
        sudo apt-get update
        sudo apt-get install -y pv tree mongodb libqdbm14
        # per travis docs, mongodb and redis should already be installed and started from services key in bionic, but this isn't working.  explicitly install.
        # the latest version of redis-server now binds to ipv6 which is not supported on travis (disabled). redis-server will fail to start due to the this so below
        # is a work around to install it, configure to it only binds to ipv4.
        wget https://download.redis.io/releases/redis-6.0.9.tar.gz
        tar xzf redis-6.0.9.tar.gz && cd redis-6.0.9
        make && sudo make install 
        sudo cp utils/systemd-redis_server.service /etc/systemd/system/redis.service
        cd $GITHUB_WORKSPACE
        rm redis-6.0.9.tar.gz
        #sudo apt-get install redis-server || true
        #sudo systemctl stop redis-server.service
        #sudo sed -e 's/^bind.*/bind 127.0.0.1/' /etc/redis/redis.conf > redis.conf
        #sudo mv redis.conf /etc/redis/redis.conf
        sudo systemctl start redis-server.service || true
        sudo systemctl status redis-server.service
        sudo systemctl start mongodb

        # install portable ruby - required for build that will eventually be published
        # see https://github.com/NREL/OpenStudio-PAT/wiki/Pat-Build-Notes
        curl -SLO --insecure https://openstudio-resources.s3.amazonaws.com/pat-dependencies3/ruby-2.5.5-linux.tar.gz
        tar xvzf ruby-2.5.5-linux.tar.gz
        ls -l /usr/local/
        sudo rm -rf /usr/local/ruby
        sudo mv ruby /usr/local/
        ldd /usr/local/ruby/bin/ruby
        rm ruby-2.5.5-linux.tar.gz

        mkdir -p reports/rspec
        # AP: this appears to only be used for Travis/Linux so we should move it out of the docker/deployment/scripts dir
        sudo ./ci/travis/install_openstudio.sh $OPENSTUDIO_VERSION $OPENSTUDIO_VERSION_SHA $OPENSTUDIO_VERSION_EXT
        export RUBYLIB=/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/Ruby
        export ENERGYPLUS_EXE_PATH=/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/EnergyPlus/energyplus
        export PATH=/usr/local/ruby/bin:/usr/local/bin:/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/bin:${PATH}
        export GEM_HOME="$GITHUB_WORKSPACE/gems"
        export GEM_PATH="$GITHUB_WORKSPACE/gems:$GITHUB_WORKSPACE/gems/bundler/gems"
    fi
    echo "verifying os installation"
    unset BUNDLE_GEMFILE && openstudio openstudio_version

    cd ${GITHUB_WORKSPACE}/server
    printenv
    which ruby
    ruby -v
    # test openssl
    # ruby ${TRAVIS_BUILD_DIR}/ci/travis/cipher.rb
    ruby ${GITHUB_WORKSPACE}/ci/travis/verify_openstudio.rb
    
    ruby "${GITHUB_WORKSPACE}/bin/openstudio_meta" install_gems --with_test_develop --debug --verbose --use_cached_gems
    bundle -v
    # create dir for output files which will be generated in case of failure
    if [ ! -d "${GITHUB_WORKSPACE}/spec/unit-test" ]; then
      mkdir "${GITHUB_WORKSPACE}/spec/unit-test"
    fi

fi
