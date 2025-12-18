#!/bin/bash -x
set -euo pipefail
echo "The build architecture is ${ImageOS}"

# macOS 15 runner setup (arm64 host). We support both:
#  - INTEL=true  => x86_64 portable Ruby (Rosetta) + x86_64 Homebrew (/usr/local)
#  - INTEL=false => arm64 portable Ruby (native)  + arm64 Homebrew (/opt/homebrew)
INTEL="${INTEL:-false}"
  
if [ "${ImageOS}" == "ubuntu22" ] && [ "${BUILD_TYPE}" == "docker" ]; then
    echo "Installing docker compose"
    sudo rm -f /usr/local/bin/docker-compose
    curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > docker-compose
    chmod +x docker-compose
    sudo mv docker-compose /usr/local/bin
    # install pipeviewer
    sudo apt-get update
    sudo apt-get install -y pv ruby

else
    # sudo rvm implode --force  # rvm PATH rewriting interferes with portable Ruby.
    if [ "${ImageOS}" == "macos15" ]; then

        brew update > $GITHUB_WORKSPACE/spec/files/logs/brew-update.log
        brew install pv tree coreutils shared-mime-info

        if [[ "${INTEL}" == "true" ]]; then
          echo "macos15 INTEL=true => x86_64 dependencies"
          OS_ARCH_SUFFIX="Darwin-x86_64"
          MONGO_ARCH="x86_64"
          RUBY_ARCH_TARBALL="ruby-3.2.2-darwin.tar.gz"
        else
          echo "macos15 INTEL=false => arm64 dependencies"
          OS_ARCH_SUFFIX="Darwin-arm64"
          MONGO_ARCH="arm64"
          RUBY_ARCH_TARBALL="ruby-3.2.2-darwin-arm64.tar.gz"
        fi
  
        # install portable ruby - required for build that will eventually be published
        # see https://github.com/NREL/OpenStudio-PAT/wiki/Pat-Build-Notes
        # --- install portable ruby (arch-specific) ---
        # NOTE: you need these tarballs available in S3. If you only have ruby-3.2.2-darwin.tar.gz today,
        #       you’ll need to publish per-arch names (recommended) or keep a conditional mapping.
        curl -SLO --insecure "https://openstudio-resources.s3.amazonaws.com/pat-dependencies3/${RUBY_ARCH_TARBALL}"
        tar xzf "${RUBY_ARCH_TARBALL}"
        exit_status_tar=$?
        if [ $exit_status_tar -ne 0 ]; then
          echo "Error: Failed to extract Ruby 3.2.2 archive"
          exit $exit_status_tar
        fi
        sudo rm -rf /usr/local/ruby
        sudo mv ruby /usr/local/
        otool -L /usr/local/ruby/bin/ruby
        rm "${RUBY_ARCH_TARBALL}"

        # --- Install mongodb from a download (arch-specific) ---
        MONGO_TARBALL="mongodb-macos-${MONGO_ARCH}-6.0.7.tgz"
        curl -SLO "https://fastdl.mongodb.org/osx/${MONGO_TARBALL}"
        tar xvzf "${MONGO_TARBALL}"
        exit_status_tar=$?
        if [ $exit_status_tar -ne 0 ]; then
          echo "Error: Failed to extract Mongo 6.0.7 archive"
          exit $exit_status_tar
        fi

        # The extracted folder name usually matches the tarball stem.
        # Using a glob keeps it simple across arch.
        sudo cp mongodb-macos-*/bin/* /usr/local/bin/
        rm -rf mongodb-macos*

        # Install openstudio -- Use the install script that is in this repo now, the one on OpenStudio/develop has changed
        export OS_NAME="OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-${OS_ARCH_SUFFIX}"
        export OS_NAME_WITH_PLUS="$OS_NAME"
        #export OS_NAME=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-Darwin-x86_64
        #export OS_NAME_WITH_PLUS=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-Darwin-x86_64
        #curl -SL --insecure https://openstudio-ci-builds.s3-us-west-2.amazonaws.com/develop/${OS_NAME}.tar.gz -o $OS_NAME_WITH_PLUS.tar.gz
        #curl -SL --insecure https://github.com/NREL/OpenStudio/releases/download/v3.8.0/${OS_NAME}.tar.gz -o $OS_NAME_WITH_PLUS.tar.gz
        #curl -SL --insecure https://github.com/NREL/OpenStudio/releases/download/v${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/${OS_NAME}.tar.gz -o $OS_NAME_WITH_PLUS.tar.gz
        URL="https://github.com/NREL/OpenStudio/releases/download/v${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/${OS_NAME}.tar.gz"
        FILENAME="${OS_NAME_WITH_PLUS}.tar.gz"

        echo "→ Downloading OpenStudio tarball from: ${URL}"
        if ! curl -fsSL --insecure "${URL}" -o "${FILENAME}"; then
          echo "ERROR: Failed to download '${FILENAME}' from '${URL}'" >&2
          exit 1
        fi
        # OSX downloads with %2B but installs with + sign. These are the encoded chars in url strings.
        #hdiutil attach ${OS_NAME}.dmg
        #sed -i -e "s|REPLACEME|$HOME/openstudio|" ci/github-actions/install-mac.qs
        # Will install into $HOME/openstudio and RUBYLIB will be $HOME/openstudio/Ruby
        #sudo /Volumes/${OS_NAME_WITH_PLUS}/${OS_NAME_WITH_PLUS}.app/Contents/MacOS/${OS_NAME_WITH_PLUS} --script ci/github-actions/install-mac.qs
        #hdiutil detach /Volumes/${OS_NAME_WITH_PLUS} -force
        ls -l
        tar xvzf $OS_NAME_WITH_PLUS.tar.gz -C $HOME
        exit_status_tar=$?
        if [ $exit_status_tar -ne 0 ]; then
         echo "Error: Failed to extract OpenStudio archive"
         exit $exit_status_tar
        fi
        ls -l $HOME
        rm -rf $OS_NAME_WITH_PLUS.tar.gz
        export PATH="/usr/local/ruby/bin:$GITHUB_WORKSPACE/gems/bin:$HOME/$OS_NAME_WITH_PLUS/bin:$PATH"
        export RUBYLIB="$HOME/$OS_NAME_WITH_PLUS/Ruby"
        ls -l $RUBYLIB
        export GEM_HOME="$GITHUB_WORKSPACE/gems"
        export GEM_PATH="$GITHUB_WORKSPACE/gems:$GITHUB_WORKSPACE/gems/bundler/gems"

        # set the ulimit to be higher
        ulimit -a
        ulimit -n 4096
        ulimit -a

    elif [ "${ImageOS}" == "ubuntu22" ]; then
        echo "Setting up Ubuntu for unit tests and Rubocop"
        # install pipe viewer to throttle printing logs to screen (not a big deal in linux, but it is in osx)
        sudo apt-get update && sudo apt-get install -y wget gnupg software-properties-common build-essential
        #sudo wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
        #echo "deb http://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse | tee /etc/apt/sources.list.d/mongodb-org-6.0.list"
        # Import MongoDB public GPG key
        sudo wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | gpg --dearmor | sudo tee /usr/share/keyrings/mongodb-org-6.0-archive-keyring.gpg
        # Add MongoDB to the sources list
        echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-org-6.0-archive-keyring.gpg] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

        sudo apt-get update
        sudo apt-get install -y pv tree mongodb-org libqdbm14 libxml2-dev
        # explicitly install. the latest version of redis-server
        #wget https://download.redis.io/releases/redis-6.0.9.tar.gz
        #tar xzf redis-6.0.9.tar.gz && cd redis-6.0.9
        #make && sudo make install
        #sudo cp utils/systemd-redis_server.service /etc/systemd/system/redis.service
        cd $GITHUB_WORKSPACE
        #rm redis-6.0.9.tar.gz
        #sudo apt-get install redis-server || true
        #sudo systemctl stop redis-server.service
        #sudo sed -e 's/^bind.*/bind 127.0.0.1/' /etc/redis/redis.conf > redis.conf
        #sudo mv redis.conf /etc/redis/redis.conf
        #sudo systemctl start redis-server.service || true
        #sudo systemctl status redis-server.service
        sudo systemctl start mongod

        # install portable ruby - required for build that will eventually be published
        # see https://github.com/NREL/OpenStudio-PAT/wiki/Pat-Build-Notes
        curl -SLO --insecure https://openstudio-resources.s3.amazonaws.com/pat-dependencies3/ruby-3.2.2-linux.tar.gz
        tar xvzf ruby-3.2.2-linux.tar.gz
        exit_status_tar=$?
        if [ $exit_status_tar -ne 0 ]; then
         echo "Error: Failed to extract Ruby 3.2.2 archive"
         exit $exit_status_tar
        fi
        ls -l /usr/local/
        sudo rm -rf /usr/local/ruby
        sudo mv ruby /usr/local/
        ldd /usr/local/ruby/bin/ruby
        rm ruby-3.2.2-linux.tar.gz

        mkdir -p reports/rspec
        sudo ./ci/github-actions/install_openstudio.sh $OPENSTUDIO_VERSION $OPENSTUDIO_VERSION_SHA $OPENSTUDIO_VERSION_EXT
        export RUBYLIB=/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/Ruby
        export ENERGYPLUS_EXE_PATH=/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/EnergyPlus/energyplus
        export PATH=/usr/local/ruby/bin:/usr/local/bin:/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/bin:${PATH}
        export GEM_HOME="$GITHUB_WORKSPACE/gems"
        export GEM_PATH="$GITHUB_WORKSPACE/gems:$GITHUB_WORKSPACE/gems/bundler/gems"
        mkdir -p $GEM_HOME/bin
        ln -s /usr/local/ruby/bin/ruby $GEM_HOME/bin/ruby
    fi
    echo "verifying os installation"
    unset BUNDLE_GEMFILE && openstudio openstudio_version

    cd ${GITHUB_WORKSPACE}/server
    which ruby
    ruby -v
    # test openssl
    ruby ${GITHUB_WORKSPACE}/ci/github-actions/verify_openstudio.rb

    ruby "${GITHUB_WORKSPACE}/bin/openstudio_meta" install_gems --with_test_develop --debug --verbose --use_cached_gems
    bundle -v
    # create dir for output files which will be generated in case of failure
    if [ ! -d "${GITHUB_WORKSPACE}/spec/unit-test" ]; then
      mkdir "${GITHUB_WORKSPACE}/spec/unit-test"
    fi

fi
