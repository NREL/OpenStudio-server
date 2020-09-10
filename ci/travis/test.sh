#!/usr/bin/env bash

# platform-specific config here (also in setup.sh):
if [ "${TRAVIS_OS_NAME}" == "osx" ]; then
    # Dir containing openstudio
    export RUBYLIB="${HOME}/openstudio/Ruby"
    export OPENSTUDIO_TEST_EXE="${HOME}/openstudio/bin/openstudio"
    # re-export PATH, even though it's set in setup.sh. 
    export PATH="$TRAVIS_BUILD_DIR/gems/bin:/usr/local/ruby/bin:$HOME/openstudio/bin:$PATH"
    export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
    export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
    mongo_dir="/usr/local/bin"
elif [ "${TRAVIS_OS_NAME}" == "linux" ]; then
    # Dir containing openstudio
    export ENERGYPLUS_EXE_PATH=/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/EnergyPlus/energyplus
    export PATH=/usr/local/ruby/bin:/usr/bin:/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/bin:${PATH}
    export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
    export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
    export RUBYLIB="/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/Ruby"
    export OPENSTUDIO_TEST_EXE="/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/bin/openstudio"
    mongo_dir="/usr/bin"
fi

# Env variables set in setup.sh do not seem to be available in test.sh
if [ "${BUILD_TYPE}" == "docker" ]; then
    echo "Skipping tests for docker builds"
else
    # Do not report coverage from these build, use the build from docker with no excluded tags
    export SKIP_COVERALLS=true

    # run unit tests via openstudio_meta run_rspec command which attempts to reproduce the PAT local environment
    # prior to running tests, so we should not set enviroment variables here
    if [ "${BUILD_TYPE}" == "test" ];then
        ulimit -a
        echo "starting unit tests. RUBYLIB=$RUBYLIB ; OPENSTUDIO_TEST_EXE=$OPENSTUDIO_TEST_EXE"
        ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" run_rspec --debug --verbose --mongo-dir="$mongo_dir" --openstudio-exe="$OPENSTUDIO_TEST_EXE" "${TRAVIS_BUILD_DIR}/spec/unit-test"
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
        cd $TRAVIS_BUILD_DIR
        printenv
        bundle install
        echo "Beginning integration tests. RUBYLIB=$RUBYLIB ; OPENSTUDIO_TEST_EXE=$OPENSTUDIO_TEST_EXE"
        bundle exec rspec; (( exit_status = exit_status || $? ))
        exit $exit_status
    fi
fi
