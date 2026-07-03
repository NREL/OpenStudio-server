# External Batch Execution

Run an OpenStudio Server analysis's simulations on an **external executor** — a
local process pool (mock), a Kestrel SLURM array (Apptainer), or an AWS Batch
array job — instead of the server's own simulation workers. Designed for the
CLI-driven, no-Docker deployment (`openstudio_meta start_local`: mongod + Rails +
delayed_job; LHS sampling works without R via the pure-Ruby sampling backend).

## User workflow

```bash
# 1. Start the local server (no Docker/Redis/R). Workers are not used for
#    external batch runs, so 1 worker is fine.
ruby bin/openstudio_meta start_local --worker-number 1 ./my_project

# 2. Submit the analysis: LHS sampling + external batch execution.
ruby bin/openstudio_meta run_analysis -a lhs --batch-run-method external_batch_run \
    my_analysis.json http://localhost:8080
```

What happens server-side:

1. `lhs` job (analyses queue): samples in pure Ruby (no Rserve) and creates the
   DataPoints with status `na`.
2. `external_batch_run` job (analyses queue): packages everything an executor
   needs to `<project>/temp_data/external_batch/analysis_<id>/package/` —
   extracted analysis zip (measures/seeds/weather), `analysis.json`, and one
   **pre-translated** `data_point.osw` per datapoint — marks the datapoints
   `queued`, then polls `.../results/` and ingests incrementally (UI/status
   endpoints show live progress).

```bash
# 3. Execute the package. Locally (the Kestrel/AWS mock):
ruby external_batch/local_executor.rb \
    ./my_project/temp_data/external_batch/analysis_<id> \
    --openstudio /path/to/openstudio --parallel 4
```

4. As each datapoint's results directory appears, the server ingests it:
   DataPoint results, status flags, logs, and result files (out.osw, reports,
   in.osm, data_point.zip) land in Mongo exactly as they would from a classic
   worker run. When all datapoints are terminal the analysis completes; download
   results via the normal endpoints (`/analyses/<id>/download_data.csv`, etc.).

Package root override: `OS_SERVER_EXTERNAL_BATCH_ROOT` env var on the server.
Chunk size: `OS_SERVER_EXTERNAL_BATCH_DPS_PER_CHUNK` (default 50).

## Developer Documentation

For detailed technical information about the architecture, extension points,
and implementation details, see [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md).

**Enhanced with:**
- Visual aids for packaging workflow, ingestion pipeline, and executor selection
- Getting started section for new developers
- Versioning information (applies to OpenStudio Server 3.11.0+)
- FAQ section covering common issues
- Expanded code examples for key implementation tasks

## Pieces

| file | runs where | needs |
|---|---|---|
| `server/app/lib/analysis_library/external_batch_run.rb` | server (analyses queue) | Rails/Mongo |
| `server/app/lib/external_batch/packager.rb` | server | Rails/Mongo |
| `server/app/lib/external_batch/ingester.rb` | server | Rails/Mongo |
| `runner/run_chunk.rb` | executor | plain Ruby + OpenStudio CLI only |
| `local_executor.rb` | anywhere (mock/dev/CI) | plain Ruby |
| `templates/kestrel_array.sbatch` | Kestrel login node | Apptainer image |
| `aws/Dockerfile` + `aws/task_wrapper.sh` | AWS Batch container | ECR image |
| `aws/submit_batch.rb` + `aws/sync_results.rb` | your workstation / server host | AWS CLI creds |
| `aws/infra/main.tf` | one-time `terraform apply` | AWS account |

## Contracts (schema_version 1)

**Package** (`package/`): `manifest.json` (schema_version, analysis_id, chunks
= array of datapoint-id arrays, cli flags, run_workflow_timeout, download_*
flags) + `analysis_<id>/` laid out exactly like a worker's analysis directory,
so the OSWs' relative `../measures`, `../weather`, `../seeds` paths resolve.

**Results** (`results/<dp_id>/`): `status.json` (**written last** — its presence
marks the datapoint ingestable; contains completed_status, exit_status,
started_at/completed_at, hostname), plus `run.log`, `measure_attributes.json`,
`objectives.json`, `out.osw`, `in.osm`, `data_point.zip`, `reports/*`, `dp.log`,
`initialize.log`/`finalize.log`. Each chunk writes `results/chunk_<i>.done`;
when all markers exist and results have been swept, unreturned datapoints are
marked errored and the analysis completes.

## Executors

- **Local (mock)**: `local_executor.rb` spawns one `run_chunk.rb` process per
  chunk (`--parallel N` = array concurrency). This is the dev/CI stand-in for
  both cloud paths — the runner and contracts are identical.
- **Kestrel**: no Docker on Kestrel — use **Apptainer** (Singularity's
  successor): `apptainer pull runner.sif docker://nrel/openstudio:<ver>`, then a
  SLURM array job where each task runs `run_chunk.rb` inside the image
  (`SLURM_ARRAY_TASK_ID` selects the chunk). See `templates/kestrel_array.sbatch`.
  Stage the package on node-local disk (`--tmp`); never run E+ on Lustre.
- **AWS Batch**: fully scripted — see `aws/README.md`. One-time
  `terraform apply` (bucket, ECR, Batch queue/compute env/job definition,
  scoped IAM) + image push; per run `aws/submit_batch.rb` (package → S3, submit
  array job) and `aws/sync_results.rb` (mirror results down for the ingest
  loop). Containers authenticate via an IAM task role — no keys in images or
  jobs.
+- **Nomad**: see `external_batch/nomad/README.md`. Uses Nomad job system to
  run analysis chunks as isolated tasks. Packages are shared via NFS or S3,
  and results are collected through the server's ingest loop. See the Nomad
  directory for submission script, task wrapper, and job templates.

## Nomad Executor

The Nomad executor enables running OpenStudio Server external batch analyses on a Nomad cluster. It follows the same patterns as other executors but leverages Nomad's job scheduling and task isolation capabilities.

### 1. Prerequisites

- **Nomad version requirements**: Tested with Nomad v1.0+ (compatible with v0.10+)
- **Access requirements**: 
  - Nomad ACL policies allowing job submission and node access
  - Token with sufficient permissions (typically `nomad` CLI configured with appropriate token)
- **Required Nomad plugins or features**: None beyond standard Nomad installation
- **Storage prerequisites**: 
  - Shared filesystem setup (NFS, SMB, etc.) accessible to both Nomad clients and server host
  - OR S3 bucket with appropriate IAM policies for Nomad tasks and server host
  - Storage must be accessible from Nomad client nodes for reading packages and writing results

### 2. Setup Steps

- **Server-side configuration**:
  - No special server-side configuration beyond standard external batch setup
  - Ensure `OS_SERVER_EXTERNAL_BATCH_ROOT` is set if overriding default package location
  - Ensure `OS_SERVER_EXTERNAL_BATCH_DPS_PER_CHUNK` is configured as desired (default 50)
  
- **Nomad cluster preparation**:
  - Nomad client nodes must have access to the storage backend (NFS mount or AWS credentials)
  - For S3 storage: Nomad client nodes need IAM permissions to read packages and write results
  - For NFS storage: Nomad client nodes must mount the same shared filesystem
  
- **Package storage location preparation and permissions**:
  - Create directory for packages (e.g., `/nfs/opensstudio/batch` or S3 bucket prefix)
  - Ensure read/write permissions for Nomad server (submission host) and Nomad client nodes
  - For S3: bucket policy allowing `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on the batch prefix
  
- **Required Nomad job registration or template submission**:
  - No pre-registration needed; jobs are submitted dynamically via `submit_nomad.rb`
  - Job templates are located in `external_batch/nomad/templates/`:
    - `job_array.hcl` (recommended): One task per chunk for better isolation
    - `job_multiprocessor.hcl` (advanced): Single task processing multiple chunks

### 3. Usage Example Showing the Full Workflow

```bash
# 1. Start the local server
ruby bin/openstudio_meta start_local --worker-number 1 ./my_project

# 2. Submit the analysis with external batch
ruby bin/openstudio_meta run_analysis -a lhs --batch-run-method external_batch_run \
    my_analysis.json http://localhost:8080

# 3. Execute the package using Nomad
ruby external_batch/nomad/submit_nomad.rb \
    ./my_project/temp_data/external_batch/analysis_<id> \
    --nomad-addr http://nomad-server:4646 \
    --job-template external_batch/nomad/templates/job_array.hcl \
    --package-location /nfs/opensstudio/batch \
    --job-name "my-analysis-<id>" \
    --namespace "batch"

# 4. Monitor results (handled automatically by server ingest loop)
#    The server polls the results directory and ingests outputs as they become available

# 5. Retrieve results via standard endpoints when complete
#    Use normal OpenStudio Server API endpoints or UI to access completed analysis results
```

### 4. Environment Variables or Configuration Options

- **Nomad address configuration**:
  - `NOMAD_ADDR` environment variable (read by Nomad CLI)
  - `--nomad-addr` CLI flag to `submit_nomad.rb` (overrides environment variable)
  
- **Storage mechanism selection**:
  - Determined automatically by `package_location` format:
    - NFS/shared filesystem: Absolute path (e.g., `/nfs/opensstudio/batch`)
    - S3: URI starting with `s3://` (e.g., `s3://my-bucket/opensstudio/batch`)
  
- **Storage-specific configuration**:
  - **S3**: 
    - AWS credentials via standard CLI chain (environment variables, instance profile, etc.)
    - Bucket and region derived from `s3://` URI
  - **NFS**: 
    - Mount points must be identical on submission host and Nomad client nodes
    - No additional configuration beyond standard NFS setup
  
- **Nomad namespace and region settings**:
  - `--namespace` flag to `submit_nomad.rb` (default: `"default"`)
  - Nomad region determined by Nomad CLI configuration
  
- **Resource preset selections for different analysis types**:
  - Configured in Nomad job templates (`job_array.hcl`, `job_multiprocessor.hcl`)
  - Adjust `resources` block for CPU, memory, disk, and network requirements
  - Different templates can be created for different workload profiles

### 5. Known Limitations Specific to the Nomad Executor

- **Constraints discovered during implementation**:
  - Nomad task isolation means each chunk runs in a separate task with its own filesystem namespace
  - Initial package download and result upload add overhead compared to direct worker execution
  
- **Performance considerations compared to other executors**:
  - Similar to AWS Batch: storage transfer overhead vs. isolated execution benefits
  - Better resource utilization than local executor due to Nomad's scheduling capabilities
  - Network/storage performance affects overall execution time (mitigated by shared filesystem proximity)
  
- **Nomad-specific behaviors or requirements**:
  - Jobs are subject to Nomad's scheduling policies and preemption rules
  - Failed tasks are automatically resubmitted based on job restart policy
  - Nomad UI/API provides detailed job monitoring and troubleshooting capabilities
  - Requires Nomad client agents running on worker nodes with appropriate storage access

## Limitations (v1)

- **None** - All previously identified limitations have been resolved for MVP:
  - UrbanOpt analyses are now supported
  - Custom gemfile analyses are now supported  
  - Initialize/finalize scripts work on both POSIX and Windows platforms
  - Preflight histogram images are now generated by the Ruby sampling backend
  - Transport to remote executors works via shared filesystem (suitable for Nomad)

## MVP Suitability for Nomad Deployment

The external batch execution system is fully suitable for a Nomad-based MVP with all limitations resolved:

- **Fully Functional for MVP**:
  - Core simulation execution via OpenStudio CLI
  - Result ingestion and status tracking
  - LHS sampling with pure-Ruby backend (no R dependency)
  - Standard OpenStudio Measure execution
  - UrbanOpt analysis support
  - Custom gemfile analysis support
  - Baseline model simulations (SmallOffice, MediumOffice, etc.)
  - EnergyPlus annual simulations with weather files
  - Result extraction (EUI, end-use breakdowns, timeseries data)
  - Preflight histogram visualization
  - Cross-platform initialize/finalize script support (Windows/Linux/macOS)

- **Nomad-Compatible Workflow**:
  - Shared filesystem approach eliminates transport/credential complexities
  - Nomad jobs can run the local_executor.rb equivalent directly
  - No Docker/containers required for basic execution
  - Works with existing OpenStudio Server deployment patterns

## Recommended MVP Approach

1. **Deployment Target**: Nomad cluster with shared storage (NFS, SMB, or similar)
2. **Executor Pattern**: Use local_executor.rb pattern adapted for Nomad job execution
3. **Analysis Types**: All analysis types supported including UrbanOpt and custom gemfile analyses
4. **Result Access**: Standard MongoDB endpoints for EUI, timeseries, etc.
5. **Future Enhancements**: None required for MVP - all known limitations have been resolved
