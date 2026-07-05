# External Batch Nomad Pipeline — Integration Plan

## Overview

Integrate the OpenStudio Server's external batch Nomad executor with the `openstudio-bem-to-surrogate-gem` parametric simulation workflow, replacing local Rserve workers with the Nomad cluster.

---

## Architecture

```
bem-to-surrogate-gem
  │  create_osa → produces OSA ZIP with parametric distributions
  │  submit_osa (modified) → --batch-run-method external_batch_run
  ▼
OpenStudio Server (Docker)
  │  1. Receives OSA, generates 'na' datapoints (LHS/DOE)
  │  2. ExternalBatchRun job: packages datapoints → package/
  │  3. Enters polling loop, waiting for results/
  ▼
Package on NFS: /nfs/opensstudio/batch/analysis_<id>/
  ├── package/   (server writes)
  └── results/   (Nomad writes, server reads)
        ▲
        │ submit_nomad.rb or equivalent
  Nomad cluster
    ├── server   (<NOMAD_SERVER_FLOATING_IP>)
    ├── client-1 (10.60.125.87)
    └── client-2 (10.60.124.175)
      Each client:
        1. task_wrapper.sh copies package locally
        2. run_chunk.rb processes each datapoint in the chunk:
           openstudio run --workflow data_point.osw
        3. Writes results/<dp_id>/status.json + chunk_<i>.done
```

---

## Phase 1: Nomad Client Infrastructure

### 1.1 Install OpenStudio CLI on Nomad Clients

**Required**: Nomad clients need `openstudio` in `$PATH` to run real simulations.

```bash
# On each client (nomad-client-1, nomad-client-2)
# Download and install OpenStudio 3.11.0 for Ubuntu
wget https://openstudio-builds.s3.amazonaws.com/3.11.0/OpenStudio-3.11.0+dd5c74a0a3-Ubuntu-22.04-x86_64.tar.gz
sudo tar xzf OpenStudio-3.11.0+dd5c74a0a3-Ubuntu-22.04-x86_64.tar.gz -C /opt/
sudo ln -s /opt/openstudio-3.11.0/bin/openstudio /usr/local/bin/openstudio
openstudio --version  # verify
```

### 1.2 Deploy Runner Scripts to All Clients

Copy `run_chunk.rb` and `task_wrapper.sh` to all Nomad clients:

```bash
for host in nomad-server nomad-client-1 nomad-client-2; do
  scp external_batch/runner/run_chunk.rb ubuntu@$host:/usr/local/bin/
  # task_wrapper.sh already at /usr/local/bin/task_wrapper.sh
  ssh ubuntu@$host "chmod +x /usr/local/bin/run_chunk.rb"
done
```

### 1.3 Update task_wrapper.sh for Real Execution

Replace the dummy `.done` file creation in `task_wrapper.sh` with a call to `run_chunk.rb`:

```bash
# After setting up LOCAL_WORK_DIR, PACKAGE_DIR, RESULTS_DIR:

log "Running chunk $CHUNK_INDEX via run_chunk.rb"
ruby /usr/local/bin/run_chunk.rb \
  --package "$PACKAGE_DIR" \
  --results "$RESULTS_DIR" \
  --chunk "$CHUNK_INDEX" \
  --openstudio "$OPENSTUDIO_CMD"

EXIT_CODE=$?
log "run_chunk.rb exited with code $EXIT_CODE"
exit $EXIT_CODE
```

### 1.4 Verify NFS Client Mounts

Confirm both Nomad clients have the NFS share mounted:

```bash
# Verify on each client
df -h /nfs/opensstudio/batch  # should show the NFS mount
```


## Phase 2: Server Configuration

### 2.1 Mount NFS into Docker Container

The Docker container currently uses a Docker volume (`osdata:/mnt/openstudio`). For seamless NFS access, either:

**Option A: Mount NFS on host, bind-mount into container** (recommended)

```bash
# On the Mac: create a local NFS mount target
mkdir -p /mnt/openstudio
# Mount the NFS export from nomad-server
sudo mount -t nfs <NOMAD_SERVER_FLOATING_IP>:/nfs/opensstudio/batch /mnt/openstudio/external_batch
```

Update `docker-compose.yml` to bind-mount instead of the Docker volume:

```yaml
services:
  web:
    volumes:
      - /mnt/openstudio/external_batch:/mnt/openstudio/external_batch
```

Set environment variable in the container:

```yaml
services:
  web:
    environment:
      - OS_SERVER_EXTERNAL_BATCH_ROOT=/mnt/openstudio/external_batch
```

**Option B: Keep using Docker volume, sync manually** (fallback)

```bash
# After Nomad writes results to NFS, sync back to Docker volume:
rsync -av ubuntu@<NOMAD_SERVER_FLOATING_IP>:/nfs/opensstudio/batch/analysis_<id>/results/ \
  /path/to/docker/volume/external_batch/analysis_<id>/results/
```

### 2.2 Configure Batch Chunk Size

Set `OS_SERVER_EXTERNAL_BATCH_DPS_PER_CHUNK` to control parallelism vs overhead:

```yaml
environment:
  - OS_SERVER_EXTERNAL_BATCH_DPS_PER_CHUNK=10  # 10 datapoints per Nomad task
```


## Phase 3: Gem Integration (openstudio-bem-to-surrogate-gem)

### 3.1 Add `--batch-run-method` Support to `submit_osa`

Modify `BuildOSA#submit_osa_file` in `lib/openstudio/bem_to_surrogate/create_osa.rb` to accept an optional `batch_run_method` parameter:

```ruby
def submit_osa_file(os_meta = nil, batch_run_method: nil)
  os_meta ||= config.external_tools.os_meta_path
  osa_json = File.join(config.project_structure.output_dir, config.project_structure.osa_json_filename)
  server_uri = config.external_tools.server_uri
  analysis_type = config.osa_settings.analysis_settings.analysis_type

  cmd = "#{os_meta} run_analysis --debug --verbose #{osa_json} #{server_uri} -a #{analysis_type}"
  cmd += " --batch-run-method #{batch_run_method}" if batch_run_method
  puts "+ #{cmd}"
  system(cmd) || abort("Command failed: #{cmd}")
end
```

### 3.2 Update `configs.yml` (optional)

Add a `batch_run_method` field to `ExternalToolsConfiguration`:

```yaml
external_tools:
  os_meta_path: /path/to/openstudio_meta
  server_uri: http://localhost:8080
  batch_run_method: external_batch_run  # nil = standard (worker-based) execution
```

### 3.3 Create `submit_osa_nomad` Rake Task

In the Rakefile, add a task that does the full Nomad pipeline:

```ruby
desc 'Create OSA, submit with external_batch_run, and submit package to Nomad'
task :submit_osa_nomad do
  base = OpenStudio::BEMToSurrogate::Base.from_yaml
  base.build_osa.create_osa_file
  osa = base.build_osa

  # 1. Submit to server with external_batch_run
  osa.submit_osa_file(batch_run_method: 'external_batch_run')

  # 2. Poll for package creation (server creates it asynchronously)
  #    The server creates: <external_batch_root>/analysis_<id>/package/
  analysis_id = wait_for_package(base.project_structure.analysis_id)
  batch_dir = external_batch_dir(analysis_id)

  # 3. Submit package to Nomad
  nomad_submit(batch_dir)
end
```

### 3.4 Helper: Poll for Package

```ruby
def wait_for_package(analysis_id, timeout: 300, interval: 5)
  ext_root = ENV['OS_SERVER_EXTERNAL_BATCH_ROOT'] || '/mnt/openstudio/external_batch'
  start = Time.now
  loop do
    pkg_dir = File.join(ext_root, "analysis_#{analysis_id}", 'package', 'manifest.json')
    return analysis_id if File.exist?(pkg_dir)
    raise "Timeout waiting for package" if Time.now - start > timeout
    sleep interval
  end
end
```

### 3.5 Helper: Submit to Nomad

```ruby
def nomad_submit(batch_dir, opts = {})
  nomad_addr = opts[:nomad_addr] || ENV.fetch('NOMAD_ADDR', 'http://localhost:4646')
  package_location = opts[:package_location] || '/nfs/opensstudio/batch'
  job_template = opts[:job_template] || File.expand_path('../external_batch/nomad/templates/job_array.hcl')
  submit_script = File.expand_path('../external_batch/nomad/submit_nomad.rb')

  cmd = [
    "ruby #{submit_script}",
    batch_dir,
    "--nomad-addr #{nomad_addr}",
    "--package-location #{package_location}",
    "--job-template #{job_template}"
  ].join(' ')

  puts "+ #{cmd}"
  system(cmd) || abort("Nomad submission failed")
end
```

### 3.6 Helper: Monitor Nomad Job and Wait for Completion

Add a task to check Nomad job status and wait until all allocations complete:

```ruby
desc 'Monitor Nomad job until completion'
task :monitor_nomad, [:job_id] do |t, args|
  job_id = args[:job_id]
  loop do
    status = `nomad job status #{job_id} 2>&1`
    puts status
    break if status.include?('Status        = dead') || status.include?('Complete')
    sleep 10
  end
  puts "Job #{job_id} complete"
end
```


## Phase 4: Operational Workflow

### 4.1 End-to-End Parametric Sweep with Nomad

```bash
# 1. Define your sweep
rake create_measure_json           # from spreadsheet
rake create_parametric_json        # from parametric spreadsheet CSV
rake create_osm                    # seed model
rake create_osw                    # workflow JSON
rake create_osa                    # analysis ZIP

# 2. Submit to server as external batch
rake submit_osa_nomad              # new: submits + submits to Nomad

# 3. Monitor
nomad job status osaf-nomad-analysis-<id>
nomad alloc logs -stderr <alloc_id>

# 4. Download results (same as before)
rake download_results
rake enrich_results_csv
```

### 4.2 Interactive Session Flow

```
User Machine (Mac)
  │
  ├── bem-to-surrogate-gem/
  │     └── rake submit_osa_nomad
  │           │
  │           ├── 1. openstudio_meta run_analysis ... --batch-run-method external_batch_run
  │           │       │
  │           │       └── OpenStudio Server (Docker) creates analysis + packages it
  │           │
  │           ├── 2. Poll until package/ exists on NFS
  │           │
  │           └── 3. ruby submit_nomad.rb ...  →  nomad job run
  │                       │
  │                       └── Nomad cluster runs simulations
  │
  └── rake download_results  (after completion)
```

### 4.3 Failure Recovery

- **Server times out before Nomad finishes**: Happens when the `ExternalBatchRun` polling loop ends but Nomad is still running. Solution: set `osaf_settings.sleep_interval` lower (default 5s) and adjust timeout or rerun `ExternalBatch::Ingester` on existing results.
- **Nomad task fails**: `run_chunk.rb` handles individual datapoint failures gracefully (marks them `completed_status: "Fail"`, continues chunk). Check `results/<dp_id>/status.json` and `out.osw`.
- **NFS out of sync**: If server and Nomad don't share the same NFS mount, use `sync_results.rb` or `rsync` to transfer results back.


## Phase 5: File Modifications Summary

| File | Change |
|------|--------|
| `bem-to-surrogate-gem/lib/openstudio/bem_to_surrogate/create_osa.rb` | Add `batch_run_method:` param to `submit_osa_file` |
| `bem-to-surrogate-gem/lib/openstudio/bem_to_surrogate/config.rb` | Add `batch_run_method` to `ExternalToolsConfiguration` |
| `bem-to-surrogate-gem/configs.yml.template` | Add `batch_run_method` field |
| `bem-to-surrogate-gem/Rakefile` | Add `submit_osa_nomad`, `monitor_nomad` tasks |
| `OpenStudio-server/external_batch/nomad/task_wrapper.sh` | Replace dummy `.done` with real `run_chunk.rb` call |
| `OpenStudio-server/docker-compose.yml` | Bind-mount NFS and set env vars |
| `OpenStudio-server/external_batch/nomad/submit_nomad.rb` | Minor fixes if needed (e.g., chdir to batch_dir) |


## Phase 6: Verification Steps

1. **Unit test**: `run_chunk.rb --package <test_pkg> --results <tmp_dir> --chunk 0` with a mock OpenStudio
2. **Local end-to-end**: Use `local_executor.rb` to verify packaging + ingestion without Nomad
3. **Nomad dry run**: `nomad job plan rendered_job.hcl` to validate template
4. **Single chunk Nomad**: Submit 1-chunk analysis, verify results appear
5. **Multi-chunk Nomad**: Submit analysis with multiple chunks, verify all complete
6. **Full gem integration**: `rake submit_osa_nomad` → wait → `rake download_results`

---

## Appendix: Key Paths and URLs

| Resource | Location |
|----------|----------|
| Nomad server | `http://<NOMAD_SERVER_FLOATING_IP>:4646` |
| NFS export (server) | `nomad-server:/nfs/opensstudio/batch` |
| NFS mount (clients) | `/nfs/opensstudio/batch` |
| Server external batch root | `/mnt/openstudio/external_batch` |
| Gem repo | `/Users/achapin/179D/openstudio-bem-to-surrogate-gem/` |
| OS server repo | `/Users/achapin/OpenStudio/OpenStudio-server/` |
| Runner script | `external_batch/runner/run_chunk.rb` |
| Nomad submission | `external_batch/nomad/submit_nomad.rb` |
| Task wrapper | `external_batch/nomad/task_wrapper.sh` |
| Job template | `external_batch/nomad/templates/job_array.hcl` |
