#!/usr/bin/env bash

echo "Current directory is $(pwd)"
# echo "tree: ${GITHUB_WORKSPACE}/spec"
# tree "${GITHUB_WORKSPACE}/spec"
echo "=== PRINTING ERROR LOG REPORTS ==="

shopt -s nullglob

echo "=== PRINTING spec/files/logs/* ==="
for F in "${GITHUB_WORKSPACE}/spec/files/logs/"*
do
    echo '======================================================'
    echo $F
    echo '======================================================'
    # Limit the rate of printing the log (with pv)
    cat $F | pv -q -L 3k
    echo
done

echo "=== PRINTING /spec/unit-test/logs/*  ==="
for F in "${GITHUB_WORKSPACE}/spec/unit-test/logs/"*
do
    echo '======================================================'
    echo $F
    echo '======================================================'
    # Limit the rate of printing the log (with pv)
    cat $F | pv -q -L 3k
    echo
done


echo "=== PRINTING /spec/unit-test/logs/rails.log/*  ==="
for F in "${GITHUB_WORKSPACE}/spec/unit-test/logs/rails.log/"*
do
    echo '======================================================'
    echo $F
    echo '======================================================'
    # Limit the rate of printing the log (with pv)
    cat $F | pv -q -L 3k
    echo
done