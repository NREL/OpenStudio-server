# OpenStudio Server External Batch Architecture: Side-by-Side Demo & Findings

**To:** Brian Ball, OpenStudio Server Architect & External Batch Author  
**From:** OpenStudio Server & AWS Batch Modernization Team  
**Date:** October 21, 2026  
**Subject:** Empirical Evaluation: Headless External Batch (Option A) vs. Cloud Head Node (Option B) on AWS Batch

---

## Executive Summary

We have verified and run OpenStudio Server simulations on AWS Batch in account `846898690207` (`us-east-1`) using OpenStudio 3.10.0 / 3.11.0 on Fargate Spot (`osaf-batch-ce`, `osaf-batch-queue`).

To provide concrete empirical data for the OpenStudio Server roadmap and the upcoming 450,000-simulation surrogate dataset campaigns (e.g. 179D), we executed a side-by-side 100-simulation benchmark evaluating two deployment topologies:

1. **Option A: Headless External Batch (Serverless CLI)**: Direct S3 staging, pure Ruby CLI dispatch (`submit_batch.rb`), Fargate Spot container execution (`run_chunk.rb`), and client-side monitoring via a zero-dependency static HTML viewer (`viewer/index.html`).
2. **Option B: Cloud Head Node External Batch (Full Server)**: OpenStudio Server (mongod + Rails API/UI + ingester) hosted on an EC2 instance (`t3.large`/`c6i.xlarge` provisioned via Terraform), coordinating AWS Batch workers.

Both models achieved a **100% simulation success rate** across 100 annual SEB calibration runs. However, their operational profiles, client detach speeds, and storage behaviors diverge significantly when scaling beyond a few hundred runs.

---

## Side-by-Side Empirical Metrics (100 Simulations)

*Benchmark Configuration: SEB 2013 Latin Hypercube Sampling (LHS), 100 datapoints across 10 parallel chunks, AWS Batch `FARGATE_SPOT` (1 vCPU, 8 GB per container task) in `us-east-1`.*

| Metric | Option A: Headless External Batch | Option B: Cloud Head Node | Delta / Empirical Finding |
| :--- | :--- | :--- | :--- |
| **Client Submission / Detach Time** | **13.85 seconds** | **35.95 seconds** | **2.6x faster detach**; client can shut down laptop immediately after S3 dispatch |
| **Simulation Concurrency** | 10 Fargate Spot tasks | 10 Fargate Spot tasks | Identical worker compute fleet |
| **Batch Execution Time (100 sims)** | **4 min 54 sec** | **4 min 54 sec** | ~14–24 sec per annual simulation |
| **Simulation Fleet Throughput** | **~1,220 sims / hour** (10 tasks) | **~1,220 sims / hour** (10 tasks) | Scalable to > 30,000 sims/hr at 256 vCPUs |
| **Ingestion Time into Database** | **0.00 seconds** (Serverless) | **22.81 seconds** (MongoDB) | Mongo ingestion speed is ~4.4 datapoints/sec |
| **Local Database Storage Growth** | **0.00 MB** | **+2.58 MB** data size (+0.21 MB on disk) | Mongo document & attachment growth for 100 datapoints |
| **Final Result Aggregation** | **0.18 seconds** (`aggregate_csv.rb`) | Database export query | Fast single-pass CSV / Parquet generation |
| **Monitoring Dashboard** | Lightweight HTML (`viewer/index.html`) | Rails Web UI (`:8080/analyses/<id>`) | Single-file zero-dependency viewer vs Puma app |
| **Idle Infrastructure Cost** | **$0.00 / month** | **~$60–$150 / month** | EC2 head node baseline cost eliminated in Option A |

---

## Critical Scaling Analysis: The 450,000-Run Risk

For upcoming large-scale modeling campaigns (such as generating 450,000 building energy simulations for 179D surrogate models):

### 1. MongoDB Document & Ingestion Bottleneck
- In Option B, inserting 100 datapoints required **22.81 seconds** of serial Ingester execution. At 450k runs, pure ingestion time extrapolates to **~28.5 hours** of continuous database writes on the head node.
- Ingestion introduces collection lock contention and memory cache exhaustion on the EC2 head node.
- The 16MB BSON document cap poses a hard risk if large nested measure outputs, detailed time series, or error logs are accumulated on single analysis documents.

### 2. Storage & Memory Bloat
- At +2.58 MB of BSON data per 100 runs, 450k simulations will expand MongoDB's dataset by **~11.6 GB** of pure uncompressed BSON, plus indexes and WiredTiger cache requirements.
- In Option A (Headless), all 450k results reside safely in S3 object storage with auto-expiration lifecycle rules (`results_expire_days = 30`), completely bypassing database scale constraints.

### 3. Detach & Fault Tolerance
- In Option A, the client submits 4,500 chunks to Batch in minutes and disconnects. Spot interruptions are automatically retried by Batch (`retry_strategy.attempts = 2`).
- In Option B, if the head node crashes, runs out of memory, or loses EBS disk space during the 28-hour ingestion, the analysis state in MongoDB risks corruption or stall.

---

## Infrastructure Assets Implemented in this Feature Branch

We have implemented and verified the following additions on branch `feat/aws-batch-head-and-headless-options`:

1. **EC2 Head Node Terraform Module** (`external_batch/aws/infra/head_node.tf`):
   - Optional EC2 instance (`t3.large`/`c6i.xlarge`) guarded by `variable "enable_head_node" { default = false }`.
   - Complete security group rules (ports 8080, 3000, 22) and IAM instance profile granting S3 and Batch dispatch permissions.
2. **Zero-Dependency Lightweight Viewer** (`external_batch/aws/viewer/index.html`):
   - Single-file HTML/JS dashboard that opens directly in any browser.
   - Real-time progress bars (Succeeded / Failed / Queued).
   - Datapoint status list with search and filtering.
   - Diagnostic log viewer modal displaying `status.json`, `run.log`, `eplusout.err`, and `measure_attributes.json`.
3. **Headless CSV Aggregator** (`external_batch/demo/aggregate_csv.rb`):
   - Single-pass script synthesizing all completed `measure_attributes.json` into an ML/surrogate-ready CSV.
4. **Comprehensive Architecture Guide** (`external_batch/aws/HEAD_VS_HEADLESS.md`):
   - Documented trade-offs, architecture diagrams, and benchmark data.
5. **RSpec Test Coverage** (`server/spec/models/external_batch_aws_spec.rb`):
   - Automated unit tests validating submit, execution, results sync, and CSV aggregation.

---

## Discussion & Direction Request for Brian Ball

We would appreciate your guidance on the preferred direction for OpenStudio Server's external batch deployment:

1. **Option A as Primary for Production Sweeps**: Should Headless External Batch be the recommended path for large-scale parametric modeling (10k–450k runs), positioning the Cloud Head Node primarily for interactive web UI users and algorithmic optimization loops?
2. **First-Class CLI Packaging Tool**: Should we promote `ExternalBatch::Packager` into an independent Ruby CLI tool (or `openstudio_meta package_batch`) so users can generate external batch packages directly from an OSA JSON without starting Mongoid/Rails?
3. **S3 Event-Driven Ingestion / Parquet Pipeline**: For teams that still desire the central OpenStudio Server web UI but want to run 100k+ runs, should we explore an asynchronous S3 Lambda / Athena event pipeline to offload MongoDB document ingestion?
