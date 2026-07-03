#!/bin/bash
# Entrypoint for Nomad tasks = one or more chunks depending on job configuration.
#
# Required env (set via Nomad job specification):
#   PACKAGE_URI   Location where the batch package is stored (NFS path, S3 URI, etc.)
#   RESULTS_URI   Location where results should be stored
#   CHUNK_INDEX   Chunk to run (0-based index)
#
# Optional env:
#   OPENSTUDIO_CMD  OpenStudio command to use (default: openstudio)
#
# No Nomad tokens needed here: the task gets its permissions from Nomad task configuration
# (policies, capabilities, etc.)
set -euo pipefail

: "${PACKAGE_URI:?PACKAGE_URI env var is required (location of the batch package)}"
: "${RESULTS_URI:?RESULTS_URI env var is required (location to store results)}"
: "${CHUNK_INDEX:?CHUNK_INDEX env var is required (which chunk to process)}"

# Support different storage types for package/results
PACKAGE_TYPE="${PACKAGE_TYPE:-nfsmount}"  # nfsmount, s3, etc.
RESULTS_TYPE="${RESULTS_TYPE:-nfsmount}"  # nfsmount, s3, etc.

WORK="${TMPDIR:-/tmp}/osaf_nomad_chunk_${CHUNK_INDEX}"
mkdir -p "${WORK}/package" "${WORK}/results"

# Push whatever results exist even if the runner dies mid-chunk; the ingester
# only reads dp folders that contain status.json, so partial pushes are safe.
push_results() {
  echo "[task_wrapper] chunk ${CHUNK_INDEX}: pushing results to ${RESULTS_URI}"
  
  case "${RESULTS_TYPE}" in
    s3)
      aws s3 sync --only-show-errors "${WORK}/results" "${RESULTS_URI}" || true
      ;;
    *)
      # Default to rsync for NFS/local filesystem
      rsync -a --quiet "${WORK}/results/" "${RESULTS_URI}/" || true
      ;;
  esac
}
trap push_results EXIT

echo "[task_wrapper] chunk ${CHUNK_INDEX}: syncing package from ${PACKAGE_URI}"

case "${PACKAGE_TYPE}" in
  s3)
    aws s3 sync --only-show-errors "${PACKAGE_URI}/package" "${WORK}/package"
    ;;
  *)
    # Default to rsync for NFS/local filesystem
    rsync -a --quiet "${PACKAGE_URI}/package/" "${WORK}/package/"
    ;;
esac

echo "[task_wrapper] chunk ${CHUNK_INDEX}: running"

# Determine OpenStudio command
OPENSTUDIO_CMD="${OPENSTUDIO_CMD:-openstudio}"

ruby /usr/local/openstudio-batch/run_chunk.rb \
  --package "${WORK}/package" \
  --results "${WORK}/results" \
  --chunk "${CHUNK_INDEX}" \
  --openstudio "${OPENSTUDIO_CMD}"

echo "[task_wrapper] chunk ${CHUNK_INDEX}: done"