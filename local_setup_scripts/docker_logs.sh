#!/bin/bash
declare -a list="$(docker service ls -q)"
echo "$list"
for app in $list; do
  echo "$app"
  docker service logs "$app"
done
