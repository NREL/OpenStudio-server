#!/bin/bash
set -ev
if [ "${REDHAT_BUILD}" = "false" ]; then
	echo 'IN A MAC BUILD'
fi
if [ "${REDHAT_BUILD}" = "true" ]; then
	echo 'IN A REDHAT BUILD'
fi