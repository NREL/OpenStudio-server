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

## Limitations (v1)

- UrbanOpt analyses and per-analysis `gemfile` are not supported (packager raises).
- Datapoint initialize/finalize shell scripts run on POSIX executors only
  (skipped with a warning on Windows mock runs).
- Preflight histogram images are not generated by the Ruby sampling backend.
- Transport to remote executors is manual/scripted (shared dir, rsync, or
  s3 sync); no built-in S3 credential handling yet.
