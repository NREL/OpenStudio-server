#!/bin/sh

# Has this been deprecated? NL - 2014-09-29
for cpunum in $(
  cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | 
  cut -s -d, -f2- | tr ',' '\n' | sort -un); do
    echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
done
