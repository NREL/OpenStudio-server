#!/usr/bin/env bash

if [ "${BUILD_ARCH}" == "OSX" ]; then
    export RUBYLIB="${HOME}/openstudio/Ruby/"
    export RUBY_ENV=local-test
    # Do not report coverage from these build, use the build from CircleCI with no excluded tags
    export SKIP_COVERALLS=true
    if [ "${BUILD_TYPE}" == "test" ]; then

        echo 'Beginning unit tests'
        bundle exec rspec -e 'unit test'; (( exit_status = exit_status || $? ))
        echo "Completed tests with exit code $exit_status"
        exit $exit_status
    elif [ "${BUILD_TYPE}" == "integration" ]; then
        echo 'Beginning integration test'
        bundle exec rspec -e 'analysis'; (( exit_status = exit_status || $? ))
        if [ "$exit_status" = "0" ]; then
            for F in /Users/travis/build/NREL/OpenStudio-server/spec/files/logs/*; do
                echo "Deleting $F to limit verbosity in case of unit test failure"
                rm $F
            done
        fi
        exit $exit_status
    fi
elif [ "${BUILD_ARCH}" == "Ubuntu" ]; then
    if [ "${BUILD_TYPE}" == "test" ]; then
        echo 'Beginning unit tests'
        export RUBY_ENV=test
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
