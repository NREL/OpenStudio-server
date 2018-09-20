#!/usr/bin/env bash

# platform-specific config here (also in setup.sh):
## TODO should be able to remove this now that it's included in setup.sh
if [ "${TRAVIS_OS_NAME}" == "osx" ]; then
    # Dir containing openstudio
    export RUBYLIB="${HOME}/openstudio/Ruby"
    export OPENSTUDIO_TEST_EXE="${HOME}/openstudio/bin/openstudio"
#    required as of OS 2.5.1
#    export PATH="${PATH}:${HOME}/openstudio/bin"
    mongo_dir="/usr/local/bin"
elif [ "${TRAVIS_OS_NAME}" == "linux" ]; then
    # Dir containing openstudio
    export RUBYLIB="/usr/local/openstudio-${OPENSTUDIO_VERSION}/Ruby:/usr/Ruby"
    export OPENSTUDIO_TEST_EXE="/usr/local/openstudio-${OPENSTUDIO_VERSION}/bin/openstudio"
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
        echo "starting unit tests. RUBYLIB=$RUBYLIB"
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
        # AP do we need this or is this handled by the openstudio_meta build + start_server and stop_server commands?
        export RAILS_ENV=local
        #    explicitly set directory.  Probably unnecessary
        cd ./
        echo "Beginning integration tests. RUBYLIB=$RUBYLIB"
        bundle exec rspec; (( exit_status = exit_status || $? ))
        exit $exit_status
    fi
fi
