#!/bin/bash

# Define the source file on the host and the destination path within the container
source_file="kill.worker"
destination_path="/opt/openstudio/server/bin/${source_file}"

# Loop through each container that has '_worker' in its name
docker ps --format "{{.Names}}" | grep '_worker' | while read container_name; do
    echo "Copying ${source_file} to ${container_name}:${destination_path}"
    docker cp "${source_file}" "${container_name}:${destination_path}"
done
