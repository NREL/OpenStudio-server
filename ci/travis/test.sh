#!/usr/bin/env bash

if [ "${BUILD_ARCH}" == "OSX" ]; then
    export RUBYLIB="${HOME}/openstudio/Ruby/"
    bundle exec rspec; (( exit_status = exit_status || $? ))
    bundle exec rspec --tag ~requires_gecko --format documentation; (( exit_status = exit_status || $? ))

    exit $exit_status
elif [ "${BUILD_ARCH}" == "Ubuntu" ]; then
    exit_status=0
    printenv RUBYLIB
    ruby -r openstudio -e "puts 'loaded'"

    cd ~/server
    echo 'PWD:'
    echo pwd
    echo 'LS -ALT'
    echo ls -alt
    echo 'CAT GEMFILE'
    cat Gemfile
    bundle exec rspec --tag ~depends_r --tag ~depends_gecko --format documentation; (( exit_status = exit_status || $? ))
#    bundle exec rspec; (( exit_status = exit_status || $? ))
    bundle exec rake rubocop:run; (( exit_status = exit_status || $? ))

    exit $exit_status
elif [ "${BUILD_ARCH}" == "RedHat" ]; then
    echo 'Tests not wired up for Centos 6.8 Build'
	exit 1
fi
