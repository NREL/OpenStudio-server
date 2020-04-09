#!/bin/bash
declare -a list="$(docker container ls -q)"
echo "$list"
for app in $list; do
  echo "$app"
  docker logs "$app"
done
