#!/usr/bin/env bash
# do not check platform - commands should be identical for Ubuntu vs OSX

# run unit tests via openstudio_meta run_rspec command which attempts to reproduce the PAT local environment
# prior to running tests, so we should not set enviroment variables here
if [ "${BUILD_TYPE}" == "test" ];then
#    run_rspec command uses this directory for output files, which will be printed in event of failure
    mkdir ./spec/unit-test
    echo "starting unit tests"
    ruby "/Users/travis/build/NREL/OpenStudio-server/bin/openstudio_meta" run_rspec --debug --verbose --mongo-dir="/usr/local/bin" "/Users/travis/build/NREL/OpenStudio-server/spec/unit-test"
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
    export RUBYLIB="${HOME}/openstudio/Ruby/"
    #    use same environment as PAT
    export RAILS_ENV=local
    export SKIP_COVERALLS=true
    #    explicitly set directory.  Probably unnecessary
    cd ./
    echo 'Beginning integration tests'
    bundle exec rspec; (( exit_status = exit_status || $? ))
    if [ $exit_status -ne 0 ]; then
        for F in /Users/travis/build/NREL/OpenStudio-server/spec/files/logs/*; do
            echo "Deleting $F to limit verbosity in case of unit test failure"
            rm $F
        done
    fi
    exit $exit_status
fi
