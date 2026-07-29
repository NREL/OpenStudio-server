#!/bin/bash
set -euo pipefail

# Logging function
log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*" >&2
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --package-uri)
            PACKAGE_URI="$2"
            shift 2
            ;;
        --results-uri)
            RESULTS_URI="$2"
            shift 2
            ;;
        --chunk-index)
            CHUNK_INDEX="$2"
            shift 2
            ;;
        --openstudio-cmd)
            OPENSTUDIO_CMD="$2"
            shift 2
            ;;
        *)
            log "ERROR: Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "${PACKAGE_URI:-}" ]]; then
    log "ERROR: --package-uri is required"
    exit 1
fi

if [[ -z "${RESULTS_URI:-}" ]]; then
    log "ERROR: --results-uri is required"
    exit 1
fi

if [[ -z "${CHUNK_INDEX:-}" ]]; then
    CHUNK_INDEX="${NOMAD_ALLOC_INDEX:-}"
    if [[ -z "${CHUNK_INDEX:-}" ]]; then
        log "ERROR: --chunk-index is required and NOMAD_ALLOC_INDEX is not set"
        exit 1
    fi
    log "Using NOMAD_ALLOC_INDEX as chunk index: $CHUNK_INDEX"
fi

# Set defaults for optional values
OPENSTUDIO_CMD="${OPENSTUDIO_CMD:-openstudio}"
PACKAGE_TYPE="${PACKAGE_TYPE:-nfsmount}"
RESULTS_TYPE="${RESULTS_TYPE:-nfsmount}"

log "Starting Nomad task wrapper"
log "Package URI: $PACKAGE_URI"
log "Results URI: $RESULTS_URI"
log "Chunk index: $CHUNK_INDEX"
log "OpenStudio command: $OPENSTUDIO_CMD"
log "Package type: $PACKAGE_TYPE"
log "Results type: $RESULTS_TYPE"

# Determine repository root from script location
REPO_DIR="$(cd "$(dirname "$0")"/../.. && pwd)"
log "Repository root: $REPO_DIR"

# Unset Bundler environment variables that might interfere with OpenStudio CLI
unset BUNDLE_BIN_PATH BUNDLE_GEMFILE RUBYOPT RUBYLIB

# Set up OpenStudio environment (if needed)
# export OPENSTUDIO_ROOT="/opt/openstudio"  # Example - adjust as needed
# Ensure OpenStudio CLI is in PATH (assuming it's installed and available)

# Set up directories. The work dir must be unique per allocation — several
# allocations can land on the same client, and a shared /tmp path would let
# them clobber each other's workspace. Nomad provides a private per-task dir;
# outside Nomad fall back to a throwaway mktemp dir.
if [[ -n "${NOMAD_TASK_DIR:-}" ]]; then
    LOCAL_WORK_DIR="$NOMAD_TASK_DIR/work"
else
    LOCAL_WORK_DIR="$(mktemp -d /tmp/nomad_task.XXXXXX)"
    trap 'rm -rf "$LOCAL_WORK_DIR"' EXIT
fi
log "Local work dir: $LOCAL_WORK_DIR"
PACKAGE_DIR="$LOCAL_WORK_DIR/package"
RESULTS_DIR="$LOCAL_WORK_DIR/results"
mkdir -p "$PACKAGE_DIR" "$RESULTS_DIR"

# Function to normalize storage URIs
normalize_uri() {
    local uri="$1"
    # Remove trailing slashes for consistency
    echo "$uri" | sed 's:/*$::'
}

# Handle package acquisition based on package type
log "Retrieving package from $PACKAGE_URI (type: $PACKAGE_TYPE)"
PACKAGE_URI_NORMALIZED=$(normalize_uri "$PACKAGE_URI")

if [[ "$PACKAGE_TYPE" == "nfsmount" ]]; then
    # For NFS/shared filesystem, package is expected to be mounted at the URI
    if [[ ! -d "$PACKAGE_URI_NORMALIZED" ]]; then
        log "ERROR: Package directory $PACKAGE_URI_NORMALIZED not found"
        exit 2
    fi
    log "Copying package from NFS location: $PACKAGE_URI_NORMALIZED"
    # cp -a src/. dest/ includes dotfiles, preserves permissions/timestamps,
    # and does not fail on an empty source dir (a bare glob would)
    cp -a "$PACKAGE_URI_NORMALIZED/." "$PACKAGE_DIR/"
elif [[ "$PACKAGE_TYPE" == "s3" ]]; then
    # For S3, sync package from remote storage
    if [[ -z "${AWS_DEFAULT_REGION:-}" ]]; then
        log "WARNING: AWS_DEFAULT_REGION not set, hoping for EC2 instance profile or shared credentials"
    fi
    log "Syncing package from S3: $PACKAGE_URI_NORMALIZED -> $PACKAGE_DIR"
    # Use AWS CLI with retries
    max_retries=3
    for i in $(seq 1 $max_retries); do
        if aws s3 sync "$PACKAGE_URI_NORMALIZED/" "$PACKAGE_DIR/"; then
            break
        fi
        if [[ $i -eq $max_retries ]]; then
            log "ERROR: Failed to sync package from S3 after $max_retries attempts"
            exit 2
        fi
        log "WARNING: S3 sync failed, retrying ($i/$max_retries)..."
        sleep 5
    done
else
    log "ERROR: Unsupported package type: $PACKAGE_TYPE"
    exit 2
fi

# Handle result destination based on results type
log "Results will be stored to $RESULTS_URI (type: $RESULTS_TYPE)"
RESULTS_URI_NORMALIZED=$(normalize_uri "$RESULTS_URI")

if [[ "$RESULTS_TYPE" == "nfsmount" ]]; then
    # For NFS/shared filesystem, ensure results directory exists
    mkdir -p "$RESULTS_URI_NORMALIZED"
    # We'll use our local results directory and copy to NFS at the end
    RESULTS_FINAL_DIR="$RESULTS_URI_NORMALIZED"
elif [[ "$RESULTS_TYPE" == "s3" ]]; then
    # For S3, we'll sync results back at the end
    log "Will sync results to S3 at the end of processing"
    RESULTS_FINAL_DIR="$RESULTS_URI_NORMALIZED"
else
    log "ERROR: Unsupported results type: $RESULTS_TYPE"
    exit 2
fi

# Determine chunk index from Nomad environment (already provided as argument)
log "Processing chunk index: $CHUNK_INDEX"
log "Running run_chunk.rb for chunk $CHUNK_INDEX"
RUN_CHUNK="/usr/local/bin/run_chunk.rb"
if [[ ! -f "$RUN_CHUNK" ]]; then
    log "ERROR: $RUN_CHUNK not found"
    exit 3
fi

# Resolve Ruby command — prefer system Ruby, fall back to OpenStudio embedded
if command -v ruby &>/dev/null; then
    log "Using system Ruby"
    ruby "$RUN_CHUNK" \
        --package "$PACKAGE_DIR" \
        --results "$RESULTS_DIR" \
        --chunk "$CHUNK_INDEX" \
        --openstudio "$OPENSTUDIO_CMD"
    RUN_EXIT=$?
elif command -v openstudio &>/dev/null; then
    # OpenStudio bundles Ruby 3.2.2.  Use openstudio -e to run run_chunk.rb,
    # constructing ARGV explicitly (openstudio -e passes no args to ARGV).
    # openstudio --execute evaluates a Ruby string.  We build a one-liner
    # that sets ARGV and loads run_chunk.rb.
    log "Using OpenStudio embedded Ruby"
    openstudio -e \
      "ARGV = ['--package', '${PACKAGE_DIR}', '--results', '${RESULTS_DIR}', '--chunk', '${CHUNK_INDEX}', '--openstudio', '${OPENSTUDIO_CMD}']; load '${RUN_CHUNK}'"
    RUN_EXIT=$?
else
    log "ERROR: Neither ruby nor openstudio found"
    exit 5
fi
if [[ $RUN_EXIT -ne 0 ]]; then
    log "WARNING: run_chunk.rb exited with code $RUN_EXIT"
fi
# Handle result transfer based on results type
if [[ "$RESULTS_TYPE" == "s3" ]]; then
    log "Syncing results to S3: $RESULTS_DIR -> $RESULTS_FINAL_DIR"
    # Use AWS CLI with retries
    max_retries=3
    for i in $(seq 1 $max_retries); do
        if aws s3 sync "$RESULTS_DIR/" "$RESULTS_FINAL_DIR/"; then
            break
        fi
        if [[ $i -eq $max_retries ]]; then
            log "ERROR: Failed to sync results to S3 after $max_retries attempts"
            exit 4
        fi
        log "WARNING: S3 results sync failed, retrying ($i/$max_retries)..."
        sleep 5
    done
elif [[ "$RESULTS_TYPE" == "nfsmount" ]]; then
    log "Copying results to NFS location: $RESULTS_DIR -> $RESULTS_FINAL_DIR"
    # Copy results to the final NFS location (dotfile-safe, empty-dir-safe)
    cp -a "$RESULTS_DIR/." "$RESULTS_FINAL_DIR/"
fi

log "Chunk $CHUNK_INDEX completed successfully"
exit 0