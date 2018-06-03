#!/usr/bin/env bash

echo "Current directory is $(pwd)"
echo "\n=== PRINTING ERROR LOG REPORTS ===\n"

shopt -s nullglob
for F in "${TRAVIS_BUILD_DIR}/spec/files/logs/"*
do
    echo '======================================================'
    echo $F
    echo '======================================================'
    # Limit the rate of printing the log (with pv) to keep travis happy. https://github.com/travis-ci/travis-ci/issues/6018
    cat $F | pv -q -L 3k
    echo
done

for F in "${TRAVIS_BUILD_DIR}/spec/unit-test/logs/"*
do
    echo '======================================================'
    echo $F
    echo '======================================================'
    # Limit the rate of printing the log (with pv) to keep travis happy. https://github.com/travis-ci/travis-ci/issues/6018
    cat $F | pv -q -L 3k
    echo
done
