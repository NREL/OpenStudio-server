#!/bin/sh

# Change Host File Entries
ENTRY="192.168.33.10 os-server"
FILE=/etc/hosts
if grep -q "$ENTRY" $FILE; then
  echo "entry already exists"
else
  echo $ENTRY >> /etc/hosts
fi