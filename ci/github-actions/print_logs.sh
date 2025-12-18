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

LOG="/Users/runner/work/OpenStudio-server/OpenStudio-server/gems/extensions/arm64-darwin-23/3.2.0-static/bigdecimal-4.0.1/mkmf.log"
if [ -f "$LOG" ]; then
  echo "===== bigdecimal mkmf.log ====="
  cat "$LOG"
  echo "===== end mkmf.log ====="
else
  echo "mkmf.log not found at $LOG"
fi