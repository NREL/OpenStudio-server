#!/bin/bash -x
export IMAGETAG="$(ruby -e "load 'server/lib/openstudio_server/version.rb'; print OpenstudioServer::VERSION+OpenstudioServer::VERSION_EXT")"
echo $IMAGETAG
docker tag nrel/openstudio-server nrel/openstudio-server:$IMAGETAG
docker tag nrel/openstudio-rserve nrel/openstudio-rserve:$IMAGETAG
docker push nrel/openstudio-server:$IMAGETAG
docker push nrel/openstudio-rserve:$IMAGETAG