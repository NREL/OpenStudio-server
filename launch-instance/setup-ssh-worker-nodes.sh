#!/bin/bash

# Read in the ip address file to allow for testing with other files
IP_FILE=$1

echo "reading in ip_addresses from file"
while read line
do
  echo "$line"
  servertype=`echo $line | awk -F'|' '{print $1}'`
  ipaddress=`echo $line | awk -F'|' '{print $2}'`
  username=`echo $line | awk -F'|' '{print $5}'`
  password=`echo $line | awk -F'|' '{print $6}'`

  if [ $servertype != "master" ]; then
    ./setup-ssh-worker-nodes.expect $ipaddress $username $password
  fi
done < ${IP_FILE}