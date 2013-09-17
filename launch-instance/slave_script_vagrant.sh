#!/bin/sh

# Change Host File Entries
ENTRY="192.168.33.10 master"
FILE=/etc/hosts
if grep -q "$ENTRY" $FILE; then
  echo "entry already exists"
else
  echo $ENTRY >> /etc/hosts
fi

# NL Remove sudo on this command as you should already be sudo
# NL No need to restart networking if only changing host entries
# service networking restart




