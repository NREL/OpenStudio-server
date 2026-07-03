# External Batch Execution - Developer Guide

This document provides detailed technical information about the external batch execution feature for developers who want to understand, modify, or extend the system.

## Table of Contents
1. [Getting Started for Developers](#getting-started-for-developers)
2. [Versioning Information](#versioning-information)
3. [Architecture Overview](#architecture-overview)
4. [Environment Variables](#environment-variables)
5. [Packaging Process](#packaging-process)
6. [Ingestion Process](#ingestion-process)
7. [Runner Contract](#runner-contract)
8. [Executor Implementation Guide](#executor-implementation-guide)
9. [Testing Strategy](#testing-strategy)
10. [Extending the System](#extending-the-system)
11. [Troubleshooting](#troubleshooting)
12. [Visual Aids](#visual-aids)
13. [FAQ](#faq)

## Getting Started for Developers

New to external batch development? This section will help you set up a test environment and run a basic execution.

### Prerequisites
- Ruby 2.5+ (matching the server version)
- OpenStudio CLI installed and accessible in PATH
- OpenStudio Server 3.11.0+ (this documentation applies to v3.11.0 and later)
- Git

### Quick Start Test
1. Clone the repository: `git clone https://github.com/NatLabRockies/OpenStudio-server.git`
2. Start local server: `ruby bin/openstudio_meta start_local --worker-number 1 ./test_project`
3. Submit analysis: `ruby bin/openstudio_meta run_analysis -a lhs --batch-run-method external_batch_run my_analysis.json http://localhost:8080`
4. Execute package: `ruby external_batch/local_executor.rb ./test_project/temp_data/external_batch/analysis_<id> --openstudio /path/to/openstudio --parallel 2`
5. Verify results in server UI or API endpoints

### Common First-Time Tasks
- Run unit tests: `rspec spec/models/external_batch_*_spec.rb`
- Check packaging: Examine `package/` directory after `external_batch_run` job completes
- Test ingestion: Manually create `status.json` in results/ and watch ingester process it
- Modify chunk size: Set `OS_SERVER_EXTERNAL_BATCH_DPS_PER_CHUNK` environment variable

## Versioning Information

This documentation applies to **OpenStudio Server version 3.11.0 and later**.
- External batch feature introduced: OpenStudio Server 3.8.0
- Current documentation version: Based on OpenStudio Server 3.11.0
- Minimum version for all features documented here: 3.11.0
- Schema version: 1 (no changes as of 3.11.0 - all executors targeting schema version 1 remain compatible)

## Architecture Overview

The external batch execution feature decouples analysis execution from the OpenStudio Server workers by:

1. **Packaging**: Server-side preparation of everything an executor needs
2. **Execution**: External execution of the packaged work (local mock, Kestrel SLURM, AWS Batch)
3. **Ingestion**: Server-side collection and processing of results

Key components:
- `ExternalBatch::Packager`: Creates the executable package
- `ExternalBatch::Ingester`: Processes results
- `AnalysisLibrary::ExternalBatchRun`: Coordinates package→wait→ingest lifecycle
- `runner/run_chunk.rb`: Common execution unit used by all executors
- Various executor implementations (local_executor.rb, kestrel_array.sbatch, AWS Batch scripts)

### Data Flow
```
Analysis Submission
        ↓
LHS Job creates datapoints (status: na)
        ↓
ExternalBatchRun Job:
        ↓
    Packager creates package/
        ↓
    Marks datapoints queued
        ↓
    Wait loop begins
        ↓
[External Executor] processes package/
        ↓
    Writes results/ with status.json (completion signal)
        ↓
Ingester detects new results
        ↓
    Updates datapoint status/results
        ↓
Analysis completes when all datapoints terminal
```

## Environment Variables

### Server-Side Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `OS_SERVER_EXTERNAL_BATCH_ROOT` | Root directory for external batch packages/results | `<project>/temp_data/external_batch` |
| `OS_SERVER_EXTERNAL_BATCH_DPS_PER_CHUNK` | Number of datapoints per chunk | `50` |

### Executor-Specific Variables
- **Local Executor**: `OPENSTUDIO_EXE_PATH`: Path to OpenStudio CLI (defaults to `openstudio` in PATH)
- **AWS Batch**: `BATCH_S3_URI`: S3 URI of batch directory; `CHUNK_INDEX`: Index of chunk to process
- **Kestrel SLURM**: `SLURM_ARRAY_TASK_ID`: Index of chunk to process

## Packaging Process

The `ExternalBatch::Packager` class creates the executable package.

### Steps
1. **Validation**: Verifies datapoints exist (UrbanOpt and custom gemfile analyses are now supported)
2. **Directory Setup**: Creates `package/` and `results/` directories; creates `package/analysis_<id>/`
3. **Analysis Extraction**: Extracts analysis seed zip to `package/analysis_<id>/` preserving directory structure
4. **Metadata Writing**: Writes analysis.json and data_point.json; pre-translates OSWs
5. **Manifest Creation**: Creates manifest.json with schema version, analysis ID, timestamp, datapoint count, chunks, workflow timeout, CLI flags, and download flags

### Package Structure
```
package/
├── manifest.json
├── analysis_<id>/
│   ├── analysis.json
│   ├── measures/ (from seed zip)
│   ├── seeds/ (from seed zip)
│   ├── weather/ (from seed zip)
│   ├── scripts/ (from seed zip)
│   ├── lib/ (from seed zip)
│   └── data_point_<dp_id>/
│       ├── analysis.json
│       ├── data_point.json
│       └── data_point.osw (pre-translated)
└── results/ (empty initially, populated by executor)
```

### Key Design Points
- **Pre-translation**: OSWs translated server-side during packaging to avoid requiring translator gems in executors
- **Path Independence**: Relative paths in OSWs resolve correctly because package mirrors worker's expected layout
- **Idempotency**: Packaging can be safely repeated; existing packages replaced but results directory preserved
- **Efficiency**: Analysis zip extracted once per package, not per datapoint

## Ingestion Process

The `ExternalBatch::Ingester` class handles processing results from executors.

### Process Flow
1. **Polling**: Periodically checks results directory for new datapoint subdirectories
2. **Completion Detection**: Only processes directories containing `status.json` (written last by runner)
3. **Datapoint Matching**: Matches result directories to datapoints by ID
4. **Result Processing**:
   - Reads `status.json` for completion status and timestamps
   - Reads `measure_attributes.json` as datapoint results
   - Attaches result files via `ResultFile` model
   - Updates datapoint flags based on `completed_status`
   - Sets datapoint status to `:completed`
5. **Error Handling**: Marks missing results as errored after executor signals completion

### Status.json Structure
```json
{
  "schema_version": 1,
  "analysis_id": "<analysis_id>",
  "data_point_id": "<dp_id>",
  "completed_status": "Success|Invalid|Cancel|Fail",
  "exit_status": <integer>,
  "started_at": "<ISO 8601 timestamp>",
  "completed_at": "<ISO 8601 timestamp>",
  "hostname": "<hostname>"
}
```

### File Attachment Rules
Result files attached based on manifest download flags:
- `out.osw`: Always attached if `completed_status` == "Fail" OR `download_osw` == true
- `in.osm`: Attached if `download_osm` == true
- `data_point.zip`: Attached if `completed_status` == "Fail" OR `download_zip` == true
- `reports/*`: Attached if `download_reports` == true
- Log files: Always attached when available

### Chunk Completion Tracking
- Each chunk writes `results/chunk_<i>.done` when finished
- Ingester uses these markers to detect when executor has finished all work
- After all `.done` markers exist, ingester performs final sweep and marks missing datapoints as errored

## Runner Contract

`runner/run_chunk.rb` is the common execution unit used by all executors.

### Input Requirements
- `--package`: Path to package directory (containing manifest.json)
- `--results`: Path to results directory (where output should be written)
- `--chunk`: Chunk index to process (optional, resolved from environment)
- `--openstudio`: Path to OpenStudio CLI (optional, defaults to `openstudio`)

### Chunk Index Resolution
Runner determines chunk to process in this order:
1. Explicit `--chunk` argument
2. `SLURM_ARRAY_TASK_ID` environment variable (Kestrel)
3. `AWS_BATCH_JOB_ARRAY_INDEX` environment variable (AWS Batch)
4. If none set, processes ALL chunks sequentially

### Output Contract
For each datapoint in assigned chunk:
```
<results>/<dp_id>/
  status.json          // Written LAST - signals completion to ingester
  run.log
  measure_attributes.json
  objectives.json
  out.osw*             // Conditional on manifest flags or failure
  in.osm*              // Conditional on manifest flags
  data_point.zip*      // Conditional on manifest flags or failure
  reports/             // Conditional on manifest flags
  dp.log
  initialize.log       // If script exists and POSIX
  finalize.log         // If script exists and POSIX
  datapoint_final.log
  oscli_simulation.log
```
\* = Conditional based on manifest download flags or failure status

Additionally, after processing all datapoints in chunk:
```
<results>/chunk_<i>.done  // Completion marker for chunk i
```

### Execution Steps Per Datapoint
1. Record start time
2. Run datapoint initialize script (POSIX-only, skipped on Windows with warning)
3. Execute OpenStudio CLI: `openstudio run --workflow data_point.osw [flags]`
4. Capture exit status and, if successful, read `completed_status` from `out.osw`
5. Run datapoint finalize script (POSIX-only, skipped on Windows with warning)
6. Collect result files based on manifest download flags
7. Write results to temporary directory (to avoid partial reads)
8. Atomically rename temporary directory to final location
9. Write `status.json` (last - signals completion)

### Error Handling
- If any step fails, marks datapoint as `completed_status: "Fail"`
- Continues processing remaining datapoints in chunk
- After chunk completion, writes chunk done marker regardless of individual datapoint success/failure

## Executor Implementation Guide

To add a new executor type, implement:

### 1. Submission Mechanism
Transfer package to execution environment and trigger `run_chunk.rb` for each chunk, respecting chunk parallelism limits.

### 2. Execution Environment
Environment that can run Ruby, OpenStudio CLI, and POSIX shell scripts (with Windows fallback).

### 3. Result Retrieval
Make results directory available to server's ingester loop.

### Key Considerations
- **Chunk Parallelism**: Respect `--parallel` concept; each chunk independently executable
- **Environment Consistency**: Use same Ruby interpreter as server; ensure OpenStudio CLI compatibility
- **Failure Handling**: Executor failures shouldn't prevent chunk completion marking
- **Security**: Principle of least privilege; only needs read access to package, write access to results

### Example Submission Script Structure
```ruby
# Transfer package to execution environment
# For each chunk in manifest:
#   Trigger execution with:
#     ruby run_chunk.rb --package <package_path> --results <results_path> --chunk <index> --openstudio <path>
# Respect parallelism limits
```

## Testing Strategy

### Unit Tests
- Located in `spec/models/external_batch_*_spec.rb`
- Test Packager, Ingester, and ExternalBatchRun classes in isolation
- Use mocks to avoid external dependencies
- Run as part of standard CI

### Integration Tests
- **Local Executor**: `spec/models/external_batch_local_spec.rb`
  - Tests end-to-end with local_executor.rb and run_chunk.rb
  - Uses real Ruby and mocked OpenStudio CLI
- **AWS Batch**: `spec/models/external_batch_aws_spec.rb`
  - Mocks AWS CLI calls
  - Tests submission and synchronization logic
  - Runs in standard CI (no actual AWS)

### Smoke Tests
- **AWS Batch**: `spec/features/aws_batch_smoke_spec.rb`
  - End-to-end test against real AWS infrastructure
  - Requires environment variables: `AWS_BATCH_SMOKE_BUCKET`, `AWS_BATCH_SMOKE_JOB_QUEUE`, `AWS_BATCH_SMOKE_JOB_DEFINITION`
  - Optional: `AWS_BATCH_SMOKE_REGION`, `AWS_BATCH_SMOKE_AWS_CMD`
  - Skipped if variables not set (safe for CI)
  - Validates results match expected golden values

### Testing Best Practices
1. Mock external dependencies (filesystem, OpenStudio CLI, AWS CLI, etc.)
2. Focus on contracts (test packages and results follow expected format)
3. Verify error handling (test system responses to failures)
4. Validate data flow (ensure data moves analysis → package → execution → results → datapoint)
5. Test edge cases (empty analyses, single datapoint, single chunk, failure scenarios)

## Extending the System

### Adding New Result Types
1. Modify `runner/run_chunk.rb` to collect new file type
2. Modify `server/app/lib/external_batch/ingester.rb` in `attach_result_files` method to attach file
3. Consider adding manifest flag to control download behavior if appropriate

### Modifying Manifest Schema
1. Update `ExternalBatch::Packager#write_manifest` to include new fields
2. Update `runner/run_chunk.rb` to validate and use new fields (check schema version)
3. Update `server/app/lib/external_batch/ingester.rb` if needed for ingestion
4. Increment `SCHEMA_VERSION` in runner if backward compatibility is broken

### Customizing Chunking Logic
1. Modify `ExternalBatch::Packager#chunks` method
2. Consider making chunking strategy configurable via analysis options or environment variables

### Adding New Executor Types
Follow Executor Implementation Guide. Key files to create/modify:
1. Submission script (`external_batch/[executor_type]/submit_[executor_type].rb`)
2. Documentation in `external_batch/README.md`
3. Example/template in `external_batch/templates/` if applicable
4. Update `external_batch/README.md` "Pieces" table
5. Add tests as appropriate

## Troubleshooting

### Common Issues and Solutions

#### Problem: "No manifest.json at {path}"
**Cause**: Packaging step not completed or incorrect path provided
**Solution**:
- Verify analysis submission completed packaging step
- Check that `<batch_dir>/package/manifest.json` exists
- For executors, ensure correct `--package` path is provided

#### Problem: Datapoints stuck in "queued" status
**Cause**: Executor not running or not communicating results
**Solution**:
- Check executor logs for startup errors
- Verify executor can access package directory
- Check that results directory is writable and accessible to ingester
- Look for chunk done markers in results directory

#### Problem: Results not appearing in UI
**Cause**: Ingestion not working or results not complete
**Solution**:
- Check server logs for ingester activity
- Verify `status.json` files exist in results subdirectories
- Check ingester logs for errors during processing
- Verify datapoint IDs in results match analysis datapoints

#### Problem: Chunk done markers missing
**Cause**: Executor failed before completion or crashed
**Solution**:
- Check executor logs for crash information
- Verify chunk processes are completing successfully
- Look for partial results that might indicate where failure occurred
- Consider reducing chunk size to isolate problematic datapoints

#### Problem: Slow performance
**Cause**: Various factors depending on executor
**Solution**:
- Local executor: Check `--parallel` setting vs system resources
- Kestrel: Verify Apptainer image pull time, SLURM queue delays
- AWS Batch: Check compute environment scaling, ECR pull times, S3 latency
- Consider tuning `dps_per_chunk` (smaller chunks = more parallelism but higher overhead)

#### Problem: Shell script errors (initialize/finalize)
**Cause**: Scripts failing or platform incompatibility
**Solution**:
- Check script logs in results directory (`initialize.log`, `finalize.log`)
- Remember scripts are POSIX-only and skipped on Windows with warning
- Verify script permissions (should be executable)
- Check script content for environment-specific assumptions

### Debugging Tips
1. Enable verbose logging: Set `cli_verbose: true` in analysis for more OpenStudio output
2. Inspect intermediate state: Examine package directory structure, verify manifest.json contents, check pre-translated OSWs
3. Test runner directly: `ruby run_chunk.rb --package <path> --results <path> --chunk 0 --openstudio <path>`
4. Verify contracts: Check manifest.json schema_version, verify results follow expected structure, confirm status.json written last
5. Check resource limits: Ensure sufficient disk space for packages/results, verify memory limits for OpenStudio simulations, check execution environment meets OpenStudio minimum requirements

## Visual Aids

### Packaging Workflow Diagram
```
Analysis Submission
        ↓
[ExternalBatchRun Job] 
        ↓
    ┌─────────────────┐
    │   Packager      │
    └─────────────────┘
        ↓
    Validate Analysis
        ↓
    Create Package Dirs
        ↓
    Extract Seed ZIP
        ↓
    Write Metadata (analysis.json, data_point.json)
        ↓
    Pre-translate OSWs
        ↓
    Create manifest.json
        ↓
    Mark Datapoints Queued
        ↓
    Wait for Results
```

### Ingestion Pipeline Diagram
```
[Executor Writes Results]
        ↓
    results/<dp_id>/status.json  ←─┐
        ↓                         │
[Ingester Poll Loop]             │
        ↓                         │
    Detect status.json           │
        ↓                         │
    Read status.json              │
        ↓                         │
    Process Datapoint Results     │
        ↓                         │
    Attach Result Files           │
        ↓                         │
    Update Datapoint Status       │
        ↓                         │
    Check for Chunk Completion    │
        ↓                         │
    [All Chunks Done?] ←──────────┘
        ↓          ↓
      No          Yes
        ↓          ↓
  Continue    Mark Analysis
    Polling   Complete
```

### Executor Selection Flowchart
```
Start
  ↓
[Need to run external batch?]
  ↓          ↓
  No        Yes
  ↓          ↓
Use local  [What's your environment?]
  workers    ↓          ↓          ↓
        [HPC/SLURM] [AWS Cloud] [Local/Dev]
           ↓          ↓          ↓
        Kestrel    AWS Batch   Local Executor
           ↓          ↓          ↓
    (Apptainer)  (Docker)   (Ruby subprocesses)
           ↓          ↓          ↓
    Best for HPC  Best for AWS  Best for testing,
           ↓          ↓          ↓
    batch systems  batch systems  CI, and small runs
```

## FAQ

### Why are my datapoints stuck in queued status?
This usually means the executor isn't running or can't communicate results back to the server. Check:
1. Executor logs for startup errors
2. That the executor can access the package directory (read permissions)
3. That the executor can write to the results directory (write permissions)
4. That the server's ingester can access the results directory
5. Look for chunk done markers (`results/chunk_<i>.done`) - if missing, the executor hasn't finished

### How do I troubleshoot missing result files?
First verify what the executor actually produced:
1. Check the results directory structure: `results/<dp_id>/`
2. Look for `status.json` - if missing, the runner didn't complete successfully
3. Check executor logs for errors during execution
4. Verify manifest download flags match what you're expecting to receive
5. Check if files are being written to a temporary directory and not renamed properly

### What do different completed_status values mean?
- `Success`: Simulation completed normally
- `Invalid`: Input data was invalid (e.g., bad OSW file)
- `Cancel`: Execution was cancelled externally
- `Fail`: Simulation failed during execution (check EnergyPlus errors)

### How can I improve performance for large analyses?
1. **Tune chunk size**: Adjust `OS_SERVER_EXTERNAL_BATCH_DPS_PER_CHUNK` (default 50)
   - Larger chunks: Less overhead, but less parallelism
   - Smaller chunks: Better load balancing, but more overhead
2. **Optimize executor parallelism**:
   - Local: Adjust `--parallel` parameter to match available CPU cores
   - Kestrel: Optimize SLURM resource requests
   - AWS Batch: Tune compute environment instance types
3. **Consider workload characteristics**: 
   - Short-running tasks: Larger chunks reduce submission overhead
   - Long-running tasks: Smaller chunks improve fault tolerance

### What are the disk space requirements for packaging?
Disk space needed ≈ (Size of analysis seed ZIP) × (1 + overhead)
- Analysis seed ZIP: Contains measures, seeds, weather, scripts
- Overhead: ~10-20% for duplicated analysis.json and pre-translated OSWs
- Results: Approximately same size as inputs plus simulation outputs
- For typical analyses: Plan for 2-3× the size of the original analysis ZIP

### How do I add a new executor type?
Follow these steps:
1. Create a submission mechanism that transfers the package and triggers `run_chunk.rb`
2. Ensure the execution environment has Ruby, OpenStudio CLI, and filesystem access
3. Implement result synchronization back to the server
4. Handle chunk indexing via `--chunk`, `SLURM_ARRAY_TASK_ID`, or `AWS_BATCH_JOB_ARRAY_INDEX`
5. Respect the runner contract: write `status.json` last per datapoint and `chunk_<i>.done` per chunk

### Can I use external batch with UrbanOpt analyses?
No, the external batch feature does not currently support UrbanOpt analyses. The packager will reject them with an error. Use the standard OpenStudio Server workers for UrbanOpt analyses.

### How do datapoint initialize/finalize scripts work?
These are shell scripts located in `analysis/scripts/data_point/`:
- `initialize.sh`: Runs before the simulation (POSIX only)
- `finalize.sh`: Runs after the simulation (POSIX only)
- On Windows executors, these are skipped with a warning in the logs
- They receive `SCRIPT_ANALYSIS_ID` and `SCRIPT_DATA_POINT_ID` as environment variables
- Arguments are stored in corresponding `.args` files as JSON arrays

### What happens if an executor crashes mid-chunk?
The ingester uses a two-phase completion detection:
1. Individual datapoints are marked complete when their `status.json` appears
2. Chunks are marked complete when `chunk_<i>.done` appears
If an executor crashes:
- Completed datapoints in that chunk will still be processed
- The ingester will wait for the chunk done marker
- After a timeout (configurable), missing datapoints will be marked as errored
- Consider implementing executor checkpointing for long-running chunks

### How does the system handle mixed success/failure datapoints?
Each datapoint is processed independently:
- Success/Failure of one datapoint doesn't affect others
- The ingester processes each based on its individual `status.json`
- Overall analysis completes when all datapoints reach terminal states (Success, Fail, Invalid, Cancel)
- Failed datapoints still have their result files attached per manifest flags

### Is there a way to test external batch without a full executor setup?
Yes! Use the local mock executor:
```bash
ruby external_batch/local_executor.rb <batch_dir> --parallel 2
```
This simulates chunk-based execution using local Ruby subprocesses, perfect for development and testing.

### How do I verify my executor implementation is correct?
1. Check that it produces the exact directory structure expected by the ingester
2. Verify `status.json` is written LAST for each datapoint
3. Confirm chunk completion markers (`chunk_<i>.done`) are written after all datapoints in chunk
4. Test with both successful and failing datapoints
5. Validate that result file attachment matches manifest download flags
6. Ensure proper handling of Windows/POSIX differences for shell scripts
