#!/bin/bash

# Read in the ip address file to allow for testing with other files
IP_FILE=$1

echo "reading in ip_addresses from file"
while read line
do
  echo "$line"
  ipaddress=`echo $line | awk -F'|' '{print $1}'`
  username=`echo $line | awk -F'|' '{print $2}'`
  password=`echo $line | awk -F'|' '{print $3}'`
  ./setup-ssh-worker-nodes.expect $ipaddress $username $password
done < ${IP_FILE}