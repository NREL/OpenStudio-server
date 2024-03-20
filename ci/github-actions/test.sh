#!/usr/bin/env bash

# platform-specific config here (also in setup.sh):
if [ "${ImageOS}" == "macos13" ]; then
    # Dir containing openstudio
    export OS_NAME_WITH_PLUS=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-Darwin-x86_64
    export RUBYLIB="$HOME/$OS_NAME_WITH_PLUS/Ruby"
    export OPENSTUDIO_TEST_EXE="$HOME/$OS_NAME_WITH_PLUS/bin/openstudio"
    # re-export PATH, even though it's set in setup.sh. 
    export PATH="$GITHUB_WORKSPACE/gems/bin:/usr/local/ruby/bin:$HOME/$OS_NAME_WITH_PLUS/bin:$PATH"
    export GEM_HOME="$GITHUB_WORKSPACE/gems"
    export GEM_PATH="$GITHUB_WORKSPACE/gems:$GITHUB_WORKSPACE/gems/bundler/gems"
    mongo_dir="/usr/local/bin"
elif [ "${ImageOS}" == "ubuntu20" ]; then
    # Dir containing openstudio
    export ENERGYPLUS_EXE_PATH=/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/EnergyPlus/energyplus
    export PATH=/usr/local/ruby/bin:/usr/bin:/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/bin:${PATH}
    export GEM_HOME="$GITHUB_WORKSPACE/gems"
    export GEM_PATH="$GITHUB_WORKSPACE/gems:$GITHUB_WORKSPACE/gems/bundler/gems"
    export RUBYLIB="/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/Ruby"
    export OPENSTUDIO_TEST_EXE="/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/bin/openstudio"
    mongo_dir="/usr/bin"
fi

# Env variables set in setup.sh do not seem to be available in test.sh
if [ "${ImageOS}" == "docker" ]; then
    echo "Skipping tests for docker builds"
else
    # Do not report coverage from these build, use the build from docker with no excluded tags
    export SKIP_COVERALLS=true

    # run unit tests via openstudio_meta run_rspec command which attempts to reproduce the PAT local environment
    # prior to running tests, so we should not set enviroment variables here
    if [ "${BUILD_TYPE}" == "test" ];then
        ulimit -a
        echo "starting unit tests. RUBYLIB=$RUBYLIB ; OPENSTUDIO_TEST_EXE=$OPENSTUDIO_TEST_EXE"
        # Threadsafe test requires higher ulimit to avoid EMFILE error
        ulimit -n
        ulimit -n 1024
        ruby "${GITHUB_WORKSPACE}/bin/openstudio_meta" run_rspec --debug --verbose --mongo-dir="$mongo_dir" --openstudio-exe="$OPENSTUDIO_TEST_EXE" "${GITHUB_WORKSPACE}/spec/unit-test"
        exit_status=$?
        if [ $exit_status == 0 ];then
            echo "Completed unit tests successfully"
            exit 0
        fi
    #   rspec failed if we made it here:
        echo "Unit tests failed with status $exit_status"
        exit $exit_status
    elif [ "${BUILD_TYPE}" == "integration" ]; then
        #    run the analysis integration specs - everything in root directory
        #    use same environment as PAT
        export RAILS_ENV=local

        #    explicitly set directory.  Probably unnecessary
        cd $GITHUB_WORKSPACE
        bundle install
        echo "Beginning integration tests. RUBYLIB=$RUBYLIB ; OPENSTUDIO_TEST_EXE=$OPENSTUDIO_TEST_EXE"
        bundle exec rspec; (( exit_status = exit_status || $? ))
        exit $exit_status
    fi
fi
