#!/usr/bin/env bash

echo "Current directory is $(pwd)"
echo "\n=== PRINTING ERROR LOG REPORTS ===\n"

shopt -s nullglob
for F in /Users/travis/build/NREL/OpenStudio-server/spec/files/logs/*
do
    echo '======================================================'
    echo $F
    echo '======================================================'
    cat $F
    echo
done

for F in /Users/travis/build/NREL/OpenStudio-server/spec/unit-test/logs/*
do
    echo '======================================================'
    echo $F
    echo '======================================================'
    cat $F
    echo
done
