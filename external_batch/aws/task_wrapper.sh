#!/bin/bash
# Entrypoint for one AWS Batch array task = one chunk.
#
# Required env (set via the job definition / submit-time container overrides):
#   BATCH_S3_URI   s3://<bucket>/runs/analysis_<id>  (the batch dir in S3)
# Optional env:
#   CHUNK_INDEX    chunk to run; defaults to AWS_BATCH_JOB_ARRAY_INDEX (array job)
#
# No AWS keys anywhere in here: the container gets its S3 permissions from the
# IAM task role attached to the job definition (picked up automatically by the
# AWS CLI from the ECS credential endpoint).
set -euo pipefail

: "${BATCH_S3_URI:?BATCH_S3_URI env var is required (s3://bucket/prefix of the batch dir)}"
CHUNK="${CHUNK_INDEX:-${AWS_BATCH_JOB_ARRAY_INDEX:-0}}"

WORK="${TMPDIR:-/tmp}/osaf_batch_chunk_${CHUNK}"
mkdir -p "${WORK}/package" "${WORK}/results"

# Push whatever results exist even if the runner dies mid-chunk; the ingester
# only reads dp folders that contain status.json, so partial pushes are safe.
push_results() {
  aws s3 sync --only-show-errors "${WORK}/results" "${BATCH_S3_URI}/results" || true
}
trap push_results EXIT

echo "[task_wrapper] chunk ${CHUNK}: syncing package from ${BATCH_S3_URI}/package"
aws s3 sync --only-show-errors "${BATCH_S3_URI}/package" "${WORK}/package"

echo "[task_wrapper] chunk ${CHUNK}: running"
ruby /usr/local/openstudio-batch/run_chunk.rb \
  --package "${WORK}/package" \
  --results "${WORK}/results" \
  --chunk "${CHUNK}" \
  --openstudio openstudio

echo "[task_wrapper] chunk ${CHUNK}: done"
