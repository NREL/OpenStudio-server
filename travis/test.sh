#!/bin/bash
if [ "${REDHAT_BUILD}" = 'false' ]; then
	if [ "${OSX_BUILD}" = 'true' ]; then
	    export RUBYLIB="${HOME}/openstudio/Ruby/"
		bundle exec rspec
		if [ $? != 0 ]; then
		    exit 1
		fi
	fi
	if [ "${OSX_BUILD}" = 'false' ]; then
	    echo 'Tests not wired up for Ubuntu Build'
		exit 1
	fi
fi
if [ "${REDHAT_BUILD}" = 'true' ]; then
    echo 'Tests not wired up for Centos 6.8 Build'
	exit 1
fi
