#!/bin/bash
set -ev
if [ "${REDHAT_BUILD}" = "false" ]; then
	if [ "OSX_BUILD" = "true" ]; then
		brew install mongo
		mongod --config /usr/local/etc/mongod.conf
		unset BUNDLE_GEMFILE
		ruby ./bin/openstudio_meta install_gems --with_test_develop --debug --verbose
	fi
	if [ "OSX_BUILD" != "false" ]; then
		sudo apt-get update
		sudo apt-get upgrade -y
	fi
fi
if [ "${REDHAT_BUILD}" = "true" ]; then
	echo 'IN A REDHAT BUILD'
	docker pull ${OS_FLAVOR}:${OS_VERSION}
	CONTAINER_ID=$(mktemp)
	docker run --detach --volume="${PWD}":/root/openstudio-server ${RUN_OPTS} ${OS_FLAVOR}:${OS_VERSION} "/usr/lib/systemd/systemd" > "${CONTAINER_ID}"
	docker exec --tty "$(cat ${CONTAINER_ID})" env TERM=xterm ruby ~/openstudio-server/bin/openstudio_meta install_gems --with_test_develop --debug --verbose
fi
