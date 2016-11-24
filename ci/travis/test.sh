#!/bin/bash
if [ "${REDHAT_BUILD}" = 'false' ]; then
	if [ "${OSX_BUILD}" = 'true' ]; then
		bundle exec rspec
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
