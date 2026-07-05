# Nomad Executor for External Batch

This directory contains the Nomad executor implementation for OpenStudio's external batch feature.

## Components

1. **submit_nomad.rb** - Job submission script
2. **task_wrapper.sh** - Task wrapper script that runs inside Nomad tasks
3. **templates/** - Nomad job specification templates:
   - `job_array.hcl` - Standard array job approach (recommended)
   - `job_multiprocessor.hcl` - Multiprocessor approach (advanced)
4. **Result Handling** - Mechanisms for getting results back to server

## Overview

The Nomad executor follows the same patterns as existing executors (AWS Batch, Local, Kestrel):

1. **Packaging**: The server uses `ExternalBatch::Packager` to create a package directory containing:
   - `manifest.json` - Analysis description and chunk definitions
   - Other analysis files needed for execution

2. **Submission**: `submit_nomad.rb`:
   - Uploads the package to a Nomad-accessible location (NFS, S3, etc.)
    - Renders a Nomad job template with analysis-specific parameters
    - Submits the job via the Nomad HTTP API (2-step: `POST /v1/jobs/parse` for HCL→JSON, then `POST /v1/jobs` with the parsed JSON)
    - Returns the Nomad job ID for tracking

3. **Execution**: Nomad runs the `task_wrapper.sh` script:
   - Downloads the package from the shared location
   - Sets up the execution environment
   - Executes `runner/run_chunk.rb` for the assigned chunk
   - Uploads results back to the shared location
   - Exits with appropriate status codes

4. **Result Handling**: Results are made available to the server's ingest loop via:
   - Shared filesystem (NFS) - results directory is directly accessible
   - Cloud storage (S3) - requires sync mechanism similar to AWS Batch executor
   - Other storage mechanisms as appropriate for the infrastructure

## Usage

### Prerequisites

- Nomad cluster (v0.10+ recommended)
- Nomad CLI installed and configured (optional — the submission script uses the HTTP API, but the CLI is useful for debugging)
- Package location accessible to both submission host and Nomad clients (NFS, S3, etc.)
- Docker container or static binary with OpenStudio CLI and Ruby (for task_wrapper.sh)

### Submission

```bash
ruby external_batch/nomad/submit_nomad.rb <batch_dir> \
  --nomad-addr http://nomad-server:4646 \
  --namespace <namespace> \
  --job-template external_batch/nomad/templates/job_array.hcl \
  --package-location /nfs/opensstudio/batch  # or s3://my-bucket/batch
```

### Result Collection

Depending on your storage backend:

**NFS/Shared Filesystem**:
- Results are automatically available at `<package-location>/analysis_<id>/results`
- No additional sync needed; server can poll this directory directly

**S3/Cloud Storage**:
- Need a sync mechanism similar to `aws/sync_results.rb`
- Could implement as a separate process or Nomad job
- Example: Periodic `aws s3 sync` from S3 to server's results directory

## Templates

### job_array.hcl (Recommended)

Creates a task group with `count = NUM_CHUNKS`, where each task instance:
- Processes one chunk (using `${NOMAD_TASK_INDEX}` for chunk identification)
- Has isolated resources and failure domains
- Can be independently restarted/scaled

### job_multiprocessor.hcl

Creates a single task group that processes multiple chunks:
- More complex chunk distribution logic needed in task wrapper
- Less failure isolation (if one chunk fails, entire task may need restart)
- Potentially more efficient resource usage for very small chunks

## Configuration & Environment Variables

### Submission Script (`submit_nomad.rb`)

Required arguments:
- `BATCH_DIR` - Path to the batched analysis directory
- `--nomad-addr` - Nomad server address (e.g., http://localhost:4646)
- `--job-template` - Path to Nomad job template file

Optional arguments:
- `--namespace` - Nomad namespace (default: "default")
- `--job-name` - Custom job name (default: osaf-nomad-analysis-<id>)
- `--package-location` - Where to store/retrieve packages (NFS path, S3 URI, etc.)
- `--ssh-host` - SSH host for rsync bridge (e.g., `ubuntu@<NOMAD_SERVER_FLOATING_IP>`); overrides `OS_SERVER_NOMAD_SSH_HOST` env var
- `--ssh-key` - SSH key path for rsync (default: /config/ssh/id_rsync)
- `--dry-run` - Print the commands without executing them

### Task Wrapper (`task_wrapper.sh`)

Required environment variables (set in job template):
- `PACKAGE_URI` - Location where the batch package is stored
- `RESULTS_URI` - Location where results should be stored
- `CHUNK_INDEX` - Which chunk to process (0-based)

Optional environment variables:
- `PACKAGE_TYPE` - Storage type for package (default: "nfsmount", alternatives: "s3")
- `RESULTS_TYPE` - Storage type for results (default: "nfsmount", alternatives: "s3")
- `OPENSTUDIO_CMD` - OpenStudio command to use (default: "openstudio")

### Nomad Job Template Variables

Templates use the following placeholders:
- `{{ANALYSIS_ID}}` - Analysis ID from manifest
- `{{NUM_CHUNKS}}` - Number of chunks from manifest
- `{{JOB_NAME}}` - Job name (from submission script or default)
- `{{NAMESPACE}}` - Nomad namespace
- `{{PACKAGE_URI}}` - Package location URI
- `{{RESULTS_URI}}` - Results location URI

## Result Handling Mechanisms

### Option 1: Shared Filesystem (NFS) - Recommended for On-Prem

1. Package location: `/nfs/opensstudio/batch/analysis_<id>/package`
2. Results location: `/nfs/opensstudio/batch/analysis_<id>/results`
3. Nomad client nodes mount the same NFS share
4. Task wrapper reads/writes directly to these paths
5. Server's ingest loop polls `/nfs/opensstudio/batch/analysis_<id>/results/`

### Option 2: Cloud Storage (S3) - Recommended for Cloud

1. Package location: `s3://<bucket>/batch/analysis_<id>/package`
2. Results location: `s3://<bucket>/batch/analysis_<id>/results`
3. Task wrapper uses AWS CLI to sync package down and results up
4. Requires Nomad tasks to have AWS permissions (via IAM roles for EC2, IRSA for EKS, etc.)
5. Server uses a sync process (like `sync_results.rb`) to pull results from S3

### Option 3: Hybrid Approach

1. Package distributed via shared filesystem or Nomad volumes
2. Results uploaded to cloud storage
3. Server pulls results from cloud storage

## Implementation Notes

### Resource Requirements

The resource requirements in the job template should be tuned based on:
- Size/complexity of individual EnergyPlus simulations
- Number of simulations per chunk (datapoints per chunk)
- Memory requirements of OpenStudio measures being used
- Disk I/O requirements for temporary files

### Failure Handling

- Nomad automatically restarts failed tasks based on restart policy
- Task wrapper uses `trap` to ensure partial results are saved on failure
- The `run_chunk.rb` script writes `status.json` last, so partial results are safe to ignore

### Security

- Follow principle of least privilege for Nomad tasks
- Tasks only need read access to package location and write access to results location
- For S3, use IAM roles/policies with minimal required permissions
- Consider using Nomad Vault integration for secrets if needed

## Testing

See `../DEVELOPER_GUIDE.md` for testing strategies. For Nomad executor:
- Unit tests would mock Nomad CLI calls
- Integration tests would require a Nomad dev environment
- Smoke tests would need access to a Nomad cluster

## Extending

To modify this executor:
1. Update submission script for different package/result handling
2. Modify task wrapper for different execution environments
3. Adjust job templates for different Nomad features
4. Update resource allocations based on profiling