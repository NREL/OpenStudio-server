#!/bin/bash -e

while true; do
    num_vol=$(docker volume ls -q | wc -l)
    echo "number of volumes: $num_vol"
    sleep 5
done
