#!/bin/bash

# Read in the ip address file to allow for testing with other files
IP_FILE=$1
TMPFILE=tmp.$$
echo "reading in ip_addresses from file"
while read line
do
  echo "$line"
  servertype=`echo $line | awk -F'|' '{print $1}'`
  ipaddress=`echo $line | awk -F'|' '{print $2}'`
  name=`echo $line | awk -F'|' '{print $3}'`
  core=`echo $line | awk -F'|' '{print $4}'`
  username=`echo $line | awk -F'|' '{print $5}'`
  password=`echo $line | awk -F'|' '{print $6}'`

  if [ $servertype != "worker" ]; then
    echo "$line" >> $TMPFILE
  fi
  if [ $servertype != "master" ]; then
    ./setup-ssh-worker-nodes.expect $ipaddress $username $password
    case $? in
      7)
       echo "$servertype|$ipaddress|$name|$core|$username|$password|true" >> $TMPFILE
       ;;
      *)
       echo "$servertype|$ipaddress|$name|$core|$username|$password|false" >> $TMPFILE
       ;;
    esac  
  fi
done < ${IP_FILE}
mv $TMPFILE $IP_FILE