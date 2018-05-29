#!/usr/bin/env bash

if [ "${BUILD_ARCH}" == "OSX" ]; then
    # Do not report coverage from these build, use the build from CircleCI with no excluded tags
#    AP: this should not be relevent, since we're running via the run_rspec command
#    export SKIP_COVERALLS=true
    if [ "${BUILD_TYPE}" == "test" ];then
        mkdir ./spec/unit-test

        echo "starting unit tests"
        ruby "/Users/travis/build/NREL/OpenStudio-server/bin/openstudio_meta" run_rspec --debug --verbose --mongo-dir="/usr/local/bin" "/Users/travis/build/NREL/OpenStudio-server/spec/unit-test"
        exit_status=$?
        if [ $exit_status == 0 ];then
            echo "Completed unit tests successfully"
            exit 0
        fi
#       rspec failed if we made it here:
        echo "Unit tests failed with status $exit_status"
        exit $exit_status
    elif [ "${BUILD_TYPE}" == "integration" ]; then
    #    run the specs in the root directory: "integration tests"
#    AP: these env vars should only be used for "integration" build (other runs via run-rspec)
        export RUBYLIB="${HOME}/openstudio/Ruby/"
        export RAILS_ENV=local

        cd ./
        echo 'Beginning integration test'
        bundle exec rspec; (( exit_status = exit_status || $? ))
        if [ "$exit_status" = "0" ]; then
            for F in /Users/travis/build/NREL/OpenStudio-server/spec/files/logs/*; do
#                AP: exit status 0 indicates success - is this functioning as intended?
                echo "Deleting $F to limit verbosity in case of unit test failure"
                rm $F
            done
        fi
        exit $exit_status
    fi
elif [ "${BUILD_ARCH}" == "Ubuntu" ]; then
    export RUBYLIB="/usr/Ruby"
    if [ "${BUILD_TYPE}" == "test" ]; then
        echo 'Beginning unit tests'
        export RUBY_ENV=local
        # Do not report coverage from this build, use the build from CircleCI with no excluded tags
        export SKIP_COVERALLS=true
        exit_status=0
        cd ./server
        export BUNDLE_GEMFILE=./Gemfile #set correct path.  see issue 272
        bundle exec rspec --tag ~depends_r --tag ~depends_gecko --format documentation; (( exit_status = exit_status || $? ))
        bundle exec rake rubocop:run; (( exit_status = exit_status || $? ))
        exit $exit_status
    elif [ "${BUILD_TYPE}" == "integration" ]; then
        echo 'Beginning integration test'
        export RUBY_ENV=local-test
        bundle exec rspec -e 'analysis'; (( exit_status = exit_status || $? ))
        if [ "$exit_status" = "0" ]; then
            for F in /Users/travis/build/NREL/OpenStudio-server/spec/files/logs/*; do
            #                AP: exit status 0 indicates success - is this functioning as intended?
                echo "Deleting $F to limit verbosity in case of unit test failure"
                rm $F
            done
        fi
        exit $exit_status
    fi
elif [ "${BUILD_ARCH}" == "RedHat" ]; then
    echo 'Tests not wired up for Centos 6.8 Build'
	exit 1
fi
