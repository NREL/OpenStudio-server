#!/bin/bash
set -ev
if [ "${REDHAT_BUILD}" = "false" ]; then
	if [ "${OSX_BUILD}" = "true" ]; then
		brew install mongo
		ruby ./bin/openstudio_meta install_gems --with_test_develop --debug --verbose
	fi
	if [ "${OSX_BUILD}" = "false"]; then
		sudo apt-get update
		sudo apt-get upgrade -y
	fi
fi
if [ "${REDHAT_BUILD}" = "true" ]; then
	echo 'IN A REDHAT BUILD'
fi
