#!/bin/bash -x
set -euo pipefail
echo "The build architecture is ${ImageOS}"

if [ "${ImageOS}" == "ubuntu24" ] && [ "${BUILD_TYPE}" == "docker" ]; then
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
        ARCH=$(uname -m)
        case "${ARCH}" in
            arm64)
                RUBY_TARBALL="ruby-3.2.2-darwin-arm64.tar.gz"
                MONGO_ARCHIVE="mongodb-macos-arm64-8.0.12"
                MONGO_EXTRACT_DIR="mongodb-macos-aarch64-8.0.12"
                OS_ARCH="arm64"
                ;;
            x86_64)
                RUBY_TARBALL="ruby-3.2.2-darwin.tar.gz"
                MONGO_ARCHIVE="mongodb-macos-x86_64-8.0.12"
                MONGO_EXTRACT_DIR="mongodb-macos-x86_64-8.0.12"
                OS_ARCH="x86_64"
                ;;
            *)
                echo "Error: Unsupported macOS architecture '${ARCH}'" >&2
                exit 1
                ;;
        esac

        brew update > $GITHUB_WORKSPACE/spec/files/logs/brew-update.log
        brew install pv tree coreutils shared-mime-info

        # install portable ruby - required for build that will eventually be published
        # see https://github.com/NatLabRockies/OpenStudio-PAT/wiki/Pat-Build-Notes
        curl -SLO --insecure "https://openstudio-resources.s3.amazonaws.com/pat-dependencies3/${RUBY_TARBALL}"
        tar xzf "${RUBY_TARBALL}"
        exit_status_tar=$?
        if [ $exit_status_tar -ne 0 ]; then
         echo "Error: Failed to extract Ruby 3.2.2 archive"
         exit $exit_status_tar
        fi
        sudo rm -rf /usr/local/ruby
        sudo mv ruby /usr/local/
        otool -L /usr/local/ruby/bin/ruby
        rm "${RUBY_TARBALL}"

        # Ensure static archives and headers for gmp, libyaml, and openssl@3 are staged in
        # /usr/local/ruby so native gem extensions (psych, puma, etc.) link statically
        # without embedding non-portable /opt/homebrew or /usr/local/opt dylib paths.
        for pkg in gmp libyaml openssl@3; do
            brew list "${pkg}" &>/dev/null || brew install "${pkg}"
            pkg_prefix=$(brew --prefix "${pkg}")
            cp -f "${pkg_prefix}"/lib/*.a /usr/local/ruby/lib/
            cp -Rf "${pkg_prefix}"/include/* /usr/local/ruby/include/
        done

        # Replace extinit.o and encinit.o in libruby.3.2-static.a (present on arm64) with dummy
        # Init_ext/Init_enc so mkmf try_link0 checks against -lruby.3.2-static succeed without
        # undefined symbols.
        if ar -t /usr/local/ruby/lib/libruby.3.2-static.a | grep -Eq '^(extinit|encinit)\.o$'; then
            dmyext_dir=$(mktemp -d)
            printf 'void Init_ext(void) {}\nvoid Init_enc(void) {}\n' > "${dmyext_dir}/dmyext.c"
            clang -c -arch "${OS_ARCH}" "${dmyext_dir}/dmyext.c" -o "${dmyext_dir}/dmyext.o"
            ar -d /usr/local/ruby/lib/libruby.3.2-static.a extinit.o encinit.o
            ar -r /usr/local/ruby/lib/libruby.3.2-static.a "${dmyext_dir}/dmyext.o"
            ranlib /usr/local/ruby/lib/libruby.3.2-static.a
            rm -rf "${dmyext_dir}"
            if ar -t /usr/local/ruby/lib/libruby.3.2-static.a | grep -Eq '^(extinit|encinit)\.o$'; then
                echo "Error: extinit.o/encinit.o still present in libruby.3.2-static.a" >&2
                exit 1
            fi
        fi

        # Sanitize Conan/Homebrew build-runner paths in rbconfig.rb and disable pkg-config lookups
        # in mkmf so native extensions only link against /usr/local/ruby/lib static archives.
        /usr/local/ruby/bin/ruby -e '
          rbconfig = Dir.glob("/usr/local/ruby/lib/ruby/3.2.0/*-darwin*/rbconfig.rb").first
          raise "Could not find rbconfig.rb under /usr/local/ruby" unless rbconfig
          content = File.read(rbconfig)
          replaced_conan = content.gsub!(/\/Users\/runner\/work\/conan-recipes\/conan-recipes\/conan-cache\/\.conan2\/p(?:\/b)?\/[^\/\s\x27":]+\/p/, "/usr/local/ruby")
          replaced_brew = content.gsub!(/\/usr\/local\/opt\/(?:openssl@3|libyaml|gmp)/, "/usr/local/ruby")
          raise "Expected Conan or Homebrew paths in #{rbconfig}" unless replaced_conan || replaced_brew
          raise "Remaining Conan paths in #{rbconfig}" if content.include?(".conan2")
          raise "Remaining Homebrew opt paths in #{rbconfig}" if content.match?(/\/usr\/local\/opt\/(?:openssl@3|libyaml|gmp)/)
          unless content.include?("--without-pkg-config")
            patched_args = content.sub!("CONFIG[\"configure_args\"] = \" ", "CONFIG[\"configure_args\"] = \" \x27--without-pkg-config\x27 ")
            raise "Failed to inject --without-pkg-config into #{rbconfig}" unless patched_args
          end
          File.write(rbconfig, content)

          rubygems = "/usr/local/ruby/lib/ruby/3.2.0/rubygems.rb"
          rg_content = File.read(rubygems)
          {
            "require \x27rubygems/dependency_list\x27" => "autoload :DependencyList, File.expand_path(\"rubygems/dependency_list\", __dir__)",
            "require \x27rubygems/installer\x27" => "autoload :Installer, File.expand_path(\"rubygems/installer\", __dir__)",
            "require \x27rubygems/util/licenses\x27" => "autoload :Licenses, File.expand_path(\"rubygems/util/licenses\", __dir__)",
            "require \x27rubygems/name_tuple\x27" => "autoload :NameTuple, File.expand_path(\"rubygems/name_tuple\", __dir__)",
            "require \x27rubygems/request_set\x27" => "autoload :RequestSet, File.expand_path(\"rubygems/request_set\", __dir__)",
            "require \x27rubygems/resolver\x27" => "autoload :Resolver, File.expand_path(\"rubygems/resolver\", __dir__)",
            "require \x27rubygems/source\x27" => "autoload :Source, File.expand_path(\"rubygems/source\", __dir__)",
            "require \x27rubygems/source_list\x27" => "autoload :SourceList, File.expand_path(\"rubygems/source_list\", __dir__)",
            "require \x27rubygems/spec_fetcher\x27" => "autoload :SpecFetcher, File.expand_path(\"rubygems/spec_fetcher\", __dir__)"
          }.each do |old_line, new_line|
            if rg_content.include?(old_line)
              raise "Failed to restore #{new_line} in #{rubygems}" unless rg_content.sub!(old_line, new_line)
            end
          end
          File.write(rubygems, rg_content)
        '

        # Install mongodb from a download. Brew is hanging and requires building mongo. This also speeds up the builds.
        curl -SLO "https://fastdl.mongodb.org/osx/${MONGO_ARCHIVE}.tgz"
        tar xvzf "${MONGO_ARCHIVE}.tgz"
        exit_status_tar=$?
        if [ $exit_status_tar -ne 0 ]; then
         echo "Error: Failed to extract Mongo 8.0.12 archive"
         exit $exit_status_tar
        fi
        sudo mkdir -p /usr/local/bin
        sudo cp "${MONGO_EXTRACT_DIR}"/bin/* /usr/local/bin/
        rm -r mongodb-macos*

        # Install openstudio -- Use the install script that is in this repo now, the one on OpenStudio/develop has changed
        export OS_NAME=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-Darwin-${OS_ARCH}
        export OS_NAME_WITH_PLUS=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-Darwin-${OS_ARCH}
        #curl -SL --insecure https://openstudio-ci-builds.s3-us-west-2.amazonaws.com/develop/${OS_NAME}.tar.gz -o $OS_NAME_WITH_PLUS.tar.gz
        #curl -SL --insecure https://github.com/NatLabRockies/OpenStudio/releases/download/v3.8.0/${OS_NAME}.tar.gz -o $OS_NAME_WITH_PLUS.tar.gz
        #curl -SL --insecure https://github.com/NatLabRockies/OpenStudio/releases/download/v${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/${OS_NAME}.tar.gz -o $OS_NAME_WITH_PLUS.tar.gz
        URL="https://github.com/NatLabRockies/OpenStudio/releases/download/v${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/${OS_NAME}.tar.gz"
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

    elif [ "${ImageOS}" == "ubuntu24" ]; then
        echo "Setting up Ubuntu for unit tests and Rubocop"
        # install pipe viewer to throttle printing logs to screen (not a big deal in linux, but it is in osx)
        sudo apt-get update && sudo apt-get install -y wget gnupg software-properties-common build-essential
        # Import MongoDB public GPG key
        sudo wget -qO - https://www.mongodb.org/static/pgp/server-8.0.asc | gpg --dearmor | sudo tee /usr/share/keyrings/mongodb-org-8.0-archive-keyring.gpg
        # Add MongoDB to the sources list
        echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-org-8.0-archive-keyring.gpg] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

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
        # see https://github.com/NatLabRockies/OpenStudio-PAT/wiki/Pat-Build-Notes
        #curl -SLO --insecure https://openstudio-resources.s3.amazonaws.com/pat-dependencies3/ruby-3.2.2-linux.tar.gz
        curl -SLO --insecure https://openstudio-resources.s3.us-east-1.amazonaws.com/pat-dependencies3/ruby-3.2.2-ubuntu24.04-x86_64.tar.gz                             
        tar xvzf ruby-3.2.2-ubuntu24.04-x86_64.tar.gz 
        exit_status_tar=$?
        if [ $exit_status_tar -ne 0 ]; then
         echo "Error: Failed to extract Ruby 3.2.2 archive"
         exit $exit_status_tar
        fi
        ls -l /usr/local/
        sudo rm -rf /usr/local/ruby
        sudo mv ruby /usr/local/
        ldd /usr/local/ruby/bin/ruby
        rm ruby-3.2.2-ubuntu24.04-x86_64.tar.gz 

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

    #DEBUG shared libraries in packaged ruby
    ruby -v
    echo "=== RBCONFIG SNAPSHOT ==="
    ruby -rrbconfig -e 'p RbConfig::CONFIG.values_at("ruby_version","arch","LIBRUBYARG_SHARED","LIBRUBYARG_STATIC","LIBRUBY_SO","LIBRUBY_A","libdir","rubylibdir","archdir")'
    echo "=== /usr/local/ruby/lib ==="
    ls -la /usr/local/ruby/lib || true

    ruby "${GITHUB_WORKSPACE}/bin/openstudio_meta" install_gems --with_test_develop --debug --verbose --use_cached_gems
    bundle -v
    # create dir for output files which will be generated in case of failure
    if [ ! -d "${GITHUB_WORKSPACE}/spec/unit-test" ]; then
      mkdir "${GITHUB_WORKSPACE}/spec/unit-test"
    fi

fi
