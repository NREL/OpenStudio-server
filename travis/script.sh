#!/bin/bash
set -ev
if [ "${REDHAT_BUILD}" = 'false' ]; then
	if [ "${OSX_BUILD}" = 'true' ]; then
		echo 'IN AN OSX BUILD'
		brew install mongo
		unset BUNDLE_GEMFILE
		curl -SLO https://openstudio-resources.s3.amazonaws.com/pat-dependencies/OpenStudio2-1.13.0.fb588cc683-darwin.zip
		mkdir ~/openstudio
		unzip OpenStudio2-1.13.0.fb588cc683-darwin.zip -d ~/openstudio
		export RUBYLIB="${HOME}/openstudio/Ruby/:$RUBYLIB"
		ruby ./bin/openstudio_meta install_gems --with_test_develop --debug --verbose
	fi
	if [ "${OSX_BUILD}" = 'false' ]; then
		echo 'IN AN UBUNTU BUILD'
		apt-get update
		apt-get upgrade -y
	fi
fi
if [ "${REDHAT_BUILD}" = 'true' ]; then
	echo 'IN A REDHAT BUILD'
	docker pull ${OS_FLAVOR}:${OS_VERSION}
	CONTAINER_ID=$(mktemp)
	docker run --detach --volume="${PWD}":/root/openstudio-server ${RUN_OPTS} ${OS_FLAVOR}:${OS_VERSION} "/usr/lib/systemd/systemd" > "${CONTAINER_ID}"
	docker exec --tty "$(cat ${CONTAINER_ID})" env TERM=xterm ruby ~/openstudio-server/bin/openstudio_meta install_gems --with_test_develop --debug --verbose
fi
