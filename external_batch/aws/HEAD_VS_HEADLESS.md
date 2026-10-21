# OpenStudio Server AWS Batch: Head vs. Headless Architecture Guide

## Overview

When scaling OpenStudio simulations to hundreds, thousands, or hundreds of thousands of datapoints on AWS Batch, two primary operational models are available:

1. **Option A: Headless External Batch (Serverless Ruby CLI)**
2. **Option B: Cloud Head Node External Batch (Full Server)**

This document details the architectural trade-offs, operational workflows, performance characteristics, and recommended deployment scenarios for each model.

---

## Architecture Comparison

```
+--------------------------------------------------------------------------------------------------+
| OPTION A: HEADLESS EXTERNAL BATCH (Serverless CLI)                                               |
|                                                                                                  |
|  [ Workstation / CI ]                                                                            |
|          |                                                                                       |
|   (package & submit)                                                                             |
|          v                                                                                       |
|   +--------------+      submit array job       +--------------------+                            |
|   |   S3 Bucket  | <-------------------------> |  AWS Batch Fleet   |                            |
|   |  (runs/...)  |                             | (Fargate Spot/EC2) |                            |
|   +--------------+ <-------------------------> +--------------------+                            |
|          ^             download chunk &                |                                         |
|          |             upload results                  |                                         |
|  +-------------------+                                 v                                         |
|  | Lightweight HTML  |                      CloudWatch Log Streams                               |
|  | Viewer / CSV Sync |                                                                           |
|  +-------------------+                                                                           |
+--------------------------------------------------------------------------------------------------+

+--------------------------------------------------------------------------------------------------+
| OPTION B: CLOUD HEAD NODE EXTERNAL BATCH (Full Server)                                           |
|                                                                                                  |
|  [ User Browser / Workstation ]                                                                  |
|          |                                                                                       |
|    (HTTP / REST API)                                                                             |
|          v                                                                                       |
|  +-----------------------------------------------------------------------------------------+     |
|  | EC2 Head Node (t3.large / c6i.xlarge)                                                   |     |
|  |  +------------------------+  +-----------------------+  +----------------------------+  |     |
|  |  | Rails Server (UI/API)  |  | MongoDB (State & Data)|  | Background Ingester Sync   |  |     |
|  |  +------------------------+  +-----------------------+  +----------------------------+  |     |
|  +-----------------------------------------------------------------------------------------+     |
|          |                                             ^                                         |
|   (sync & submit)                                (ingest results)                                |
|          v                                             |                                         |
|   +--------------+      submit array job       +--------------------+                            |
|   |   S3 Bucket  | <-------------------------> |  AWS Batch Fleet   |                            |
|   |  (runs/...)  |                             | (Fargate Spot/EC2) |                            |
|   +--------------+ <-------------------------> +--------------------+                            |
+--------------------------------------------------------------------------------------------------+
```

---

## Detailed Model Analysis

### Option A: Headless External Batch (Serverless CLI)

Direct S3 staging and Batch dispatch driven by pure Ruby CLI scripts (`submit_batch.rb`, `run_chunk.rb`) without requiring MongoDB or Rails server instances.

#### Key Advantages:
- **Zero Database Bottleneck**: Bypasses MongoDB document size limits (16MB BSON cap), replica set sync latency, and I/O lock contention. Ideal for massive scale (e.g. 100k–500k+ runs).
- **Zero Idle Costs**: No persistent EC2 head node instance running 24/7. Costs are strictly incurred per second of active AWS Batch execution and S3 storage.
- **Instant Detach**: The client workstation packages the OSWs, issues an S3 sync, triggers `batch submit-job`, and detaches immediately.
- **Lightweight Monitoring**: Results can be monitored via AWS Batch CloudWatch logs or viewed locally in real-time with the zero-dependency `external_batch/aws/viewer/index.html`.
- **Direct Aggregation**: End outputs (`measure_attributes.json`) can be directly aggregated into Parquet, DuckDB, or CSV without database export passes.

#### Limitations:
- Best suited for static sampling analyses (LHS, Full Factorial, Sobol, Sobol-Saltelli, parametric sweeps).
- Adaptive algorithms (e.g., NSGA-II, PSO) requiring intermediate simulation evaluation loops before generating subsequent generations require a controller loop.

---

### Option B: Cloud Head Node External Batch (Full Server)

Hosts the standard OpenStudio Server stack (Puma Rails server, MongoDB, Resque background workers) on an EC2 instance in the VPC, using AWS Batch as the worker compute backend via `external_batch_run`.

#### Key Advantages:
- **Familiar UI Experience**: Project managers and building analysts can view live web UI tables, download archives, and view visualizations.
- **Standard API Integration**: Existing CLI commands (`openstudio_meta run_analysis`) and external SDK integrations work without modification.
- **Dynamic / Algorithmic Workflows**: Supports server-driven analysis algorithms where the server dynamically schedules datapoints based on prior results.
- **Centralized Data Hub**: Multi-user collaboration where team members can query simulation status and results via central REST endpoints.

#### Limitations:
- **Head Node Operating Cost**: The EC2 head instance incurs a continuous baseline cost (e.g. ~$60–$150/month for `t3.large`/`c6i.xlarge` with gp3 storage).
- **Database Scaling Ceiling**: MongoDB document ingestion for hundreds of thousands of datapoints requires significant memory, index sizing, and lock management.

---

## Trade-Off Summary

| Attribute | Option A: Headless External Batch | Option B: Cloud Head Node |
| :--- | :--- | :--- |
| **Primary Use Case** | Massive parametric runs (10k – 500k+), CI/CD, surrogate modeling | Interactive sweeps, multi-user web UI, algorithmic analyses |
| **Infrastructure Overhead** | Zero server instances (Serverless S3 + Batch) | 1 EC2 instance (`t3.large` or `c6i.xlarge`) + gp3 EBS |
| **Idle Running Cost** | $0.00 / month | ~$60 – $150 / month |
| **Client Submission Latency** | Near-instant (< 30 seconds to upload and detach) | Analysis creation + API submission + DB persistence |
| **Scalability Limit** | AWS account service quotas (vCPU/Fargate Spot limits) | MongoDB storage, indexing & BSON size overhead |
| **Monitoring Tool** | `viewer/index.html`, CloudWatch, AWS Console | OpenStudio Server Web UI (port 8080) |
| **Result Aggregation** | Direct S3 to CSV / DuckDB / Parquet | MongoDB export queries |

---

## Empirical Benchmark & Metrics Reference

The following empirical benchmark was conducted on **October 21, 2026** comparing a 100-simulation batch run (SEB 2013 LHS Calibration analysis, 100 datapoints across 10 parallel chunks) on AWS Batch (`FARGATE_SPOT`, `us-east-1` in AWS account `846898690207`):

| Evaluation Dimension | Option A: Headless External Batch | Option B: Cloud Head Node | Notes / Findings |
| :--- | :--- | :--- | :--- |
| **Client Submission / Detach Wall Time** | **13.85 seconds** | **35.95 seconds** | Headless uploads package to S3 and detaches in < 14s. Head node must generate Mongo documents, package, submit, and run local ingest. |
| **Simulation Parallelism** | 10 Fargate Spot tasks (1 vCPU, 8 GB each) | 10 Fargate Spot tasks (1 vCPU, 8 GB each) | Both models leverage identical AWS Batch Spot fleets. |
| **Total 100-Sim Batch Wall Time** | **4 min 54 sec** | **4 min 54 sec** + 23s ingest | Average single simulation time: 14–24s per annual SEB run. Batch Spot fleet ran all 100 sims concurrently. |
| **Simulation Throughput** | **~1,220 sims / hour** (10 tasks) | **~1,220 sims / hour** (10 tasks) | Scales linearly with concurrency; at 256 vCPUs throughput reaches > 30,000 sims/hr. |
| **Result Ingestion Wall Time** | **0.00 seconds** (Serverless) | **22.81 seconds** (MongoDB) | Ingestion speed into Mongo was ~4.4 datapoints/sec. |
| **Local Database Storage Growth** | **0.00 MB** (Zero DB footprint) | **+2.58 MB** data size (+0.21 MB on-disk) | Mongo document growth for 100 runs. |
| **Extrapolated Footprint at 450k Runs** | **0.00 GB DB** (S3 only) | **~11.6 GB BSON data** + indices | 450k runs in MongoDB poses severe lock contention, memory bloat, and ~28h ingest latency. |
| **Final Aggregation Wall Time** | **0.18 seconds** (Direct S3/CSV) | Database query / CSV export | `aggregate_csv.rb` synthesized 100 `measure_attributes.json` into a unified CSV in < 200ms. |
| **Monitoring Interface** | Zero-dependency static viewer (`viewer/index.html`) | Full Rails Web UI (`http://localhost:8080`) | Headless viewer runs entirely client-side without a server backend. |
| **Failure Diagnostics** | Modal tabs in `viewer/index.html` + CloudWatch streams | DataPoint detail modal in Rails UI | Both allow viewing `run.log`, `eplusout.err`, and `status.json`. |
| **Infrastructure Running Cost** | $0 idle, pay only per active Fargate Spot sec | ~$60–$150/mo EC2 head node + EBS + Batch Spot | Headless avoids persistent compute instances. |

---

## Provisioning and Deployment

### 1. Provisioning Option A (Headless Infrastructure)

```bash
cd external_batch/aws/infra
terraform init
terraform apply -var region=us-east-1 -var bucket_name=osaf-batch-846898690207
```

### 2. Provisioning Option B (Including Cloud Head Node)

Enable the optional head node resource in Terraform:

```bash
cd external_batch/aws/infra
terraform apply \
  -var region=us-east-1 \
  -var bucket_name=osaf-batch-846898690207 \
  -var enable_head_node=true \
  -var head_node_instance_type=t3.large
```

The output will display `head_node_ui_url` (e.g. `http://<public-ip>:8080`).
