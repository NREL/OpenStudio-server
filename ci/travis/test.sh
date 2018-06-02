#!/usr/bin/env bash

# platform-specific config here:
if [ "${BUILD_ARCH}" == "OSX" ]; then
    export RUBYLIB="${HOME}/openstudio/Ruby/"
    home_dir="/Users/travis/build/NREL/OpenStudio-server"
elif [ "${BUILD_ARCH}" == "OSX" ]; then
    export RUBYLIB="/usr/Ruby"
    home_dir="/home/travis/build/NREL/OpenStudio-server"
fi

# run unit tests via openstudio_meta run_rspec command which attempts to reproduce the PAT local environment
# prior to running tests, so we should not set enviroment variables here
if [ "${BUILD_TYPE}" == "test" ];then
#    run_rspec command uses this directory for output files, which will be printed in event of failure
    mkdir "$home_dir/spec/unit-test"
    echo "starting unit tests"
    ruby "$home_dir/bin/openstudio_meta" run_rspec --debug --verbose --mongo-dir="/usr/local/bin" "$home_dir/spec/unit-test"
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
    export SKIP_COVERALLS=true
    #    explicitly set directory.  Probably unnecessary
    cd ./
    echo 'Beginning integration tests'
    bundle exec rspec; (( exit_status = exit_status || $? ))
    if [ $exit_status -ne 0 ]; then
        for F in "$home_dir/spec/files/logs/*"; do
            echo "Deleting $F to limit verbosity in case of unit test failure"
            rm $F
        done
    fi
    exit $exit_status
fi
