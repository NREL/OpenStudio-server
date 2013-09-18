#!/bin/sh

# Change Host File Entries
ENTRY="localhost localhost master"
FILE=/etc/hosts
if grep -q "$ENTRY" $FILE; then
  echo "entry already exists"
else
  echo $ENTRY >> /etc/hosts
fi