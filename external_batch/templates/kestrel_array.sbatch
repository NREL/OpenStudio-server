#!/bin/bash
# ------------------------------------------------------------------------------
# TEMPLATE: Kestrel SLURM array job for an external batch package.
# One array task = one chunk from manifest.json. The runner (run_chunk.rb) is
# the same file the local mock executor uses; only the submission differs.
#
# Prereqs (once):
#   apptainer pull runner.sif docker://nrel/openstudio:<openstudio_version>
#   copy the batch dir (package/) to a place compute nodes can read, e.g.
#   /projects/<alloc>/osaf/analysis_<id>/ (or `aws s3 sync` it up and down)
#
# Submit:
#   N=$(python3 -c "import json;print(len(json.load(open('package/manifest.json'))['chunks']))")
#   sbatch --array=0-$((N-1))%<max_concurrent_tasks> kestrel_array.sbatch
#
# After completion, sync results/ back to the server host and let
# ExternalBatchRun's ingest loop pick them up (it polls results/ continuously,
# so a shared filesystem or periodic rsync both work).
# ------------------------------------------------------------------------------
#SBATCH --job-name=osaf_external_batch
#SBATCH --account=<YOUR_ALLOCATION>
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8          # size to sims-per-chunk; E+ wants ~1 core + ~8 GB per sim
#SBATCH --mem=64G
#SBATCH --tmp=100G                 # REQUIRED: node-local disk; E+ small-file I/O must not hit Lustre
#SBATCH --output=osaf_%A_%a.out

set -euo pipefail

BATCH_DIR=/projects/<YOUR_ALLOCATION>/osaf/analysis_<ANALYSIS_ID>
RUNNER_SIF=/projects/<YOUR_ALLOCATION>/osaf/runner.sif
RUNNER_RB=/projects/<YOUR_ALLOCATION>/osaf/run_chunk.rb

# Stage the package to node-local scratch (E+ I/O), write results back to the shared dir
LOCAL=${TMPDIR:-/tmp/scratch}/osaf_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}
mkdir -p "$LOCAL"
rsync -a "$BATCH_DIR/package/" "$LOCAL/package/"

# chunk index comes from SLURM_ARRAY_TASK_ID automatically
apptainer exec --bind "$LOCAL","$BATCH_DIR" "$RUNNER_SIF" \
  ruby "$RUNNER_RB" \
  --package "$LOCAL/package" \
  --results "$BATCH_DIR/results" \
  --openstudio openstudio

rm -rf "$LOCAL"
