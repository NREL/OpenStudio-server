# AWS Batch walkthrough (first-time user)

A complete, copy-pasteable path from "I have an AWS account" to "my analysis's
simulations ran on AWS Batch and the results are in my local OpenStudio Server."
Verified end-to-end on Windows 11 + Docker Desktop, 2026-07-02.

## 0. Install tools (once)

```powershell
winget install --id Amazon.AWSCLI -e
winget install --id Hashicorp.Terraform -e
# Docker Desktop must be installed and running
# then OPEN A NEW TERMINAL so PATH updates take effect
aws --version
terraform --version
```

## 1. Create CLI credentials (once, in the AWS console)

Console login is not enough — the command line needs an access key:

1. Sign in at https://console.aws.amazon.com
2. Top-right search bar → type **IAM** → open it
3. Left menu **Users** → **Create user** → name it (e.g. `osaf-batch-admin`) →
   **Attach policies directly** → check **AdministratorAccess** → create
4. Click the new user → **Security credentials** tab → **Create access key** →
   choose **Command Line Interface (CLI)** → copy both values
5. In your terminal:
   ```powershell
   aws configure
   # paste Access key ID, Secret access key; region e.g. us-east-1; output json
   aws sts get-caller-identity     # sanity check — prints your account id
   ```

Best practices: don't create keys on the root user; never commit keys or paste
them into chats/tickets; delete keys you stop using (IAM → user → Security
credentials → Deactivate/Delete).

## 2. Provision the AWS infrastructure (once)

```powershell
cd external_batch/aws/infra
terraform init
terraform apply -var region=us-east-1 -var bucket_name=osaf-batch-<YOUR_ACCOUNT_ID>
```

Type `yes` when prompted (~1 min). Note the outputs: `bucket_name`,
`ecr_repository_url`, `job_queue`, `job_definition`.

**If you get "no matching EC2 VPC found"**: your account/region has no default
VPC. Recreate it, then re-apply:
```powershell
aws ec2 create-default-vpc --region us-east-1
```

What this created (and where to see it in the console):
- **S3** → bucket `osaf-batch-<account>` — packages/results live under `runs/`
- **ECR** (search "ECR") → repository `osaf-batch-runner` — the runner image
- **Batch** (search "Batch") → compute environment `osaf-batch-ce` (scales
  0→256 vCPUs→0), job queue `osaf-batch-queue`, job definition
  `osaf-batch-runner`
- **IAM** → roles `osaf-batch-{service,instance,task}-role` — the task role is
  what the containers use for S3; it can touch nothing but `runs/*`

## 3. Build + push the runner image (once per OpenStudio version)

```powershell
cd external_batch
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT>.dkr.ecr.us-east-1.amazonaws.com
docker build -f aws/Dockerfile --build-arg OPENSTUDIO_VERSION=3.11.0 -t <ACCOUNT>.dkr.ecr.us-east-1.amazonaws.com/osaf-batch-runner:3.11.0 .
docker push <ACCOUNT>.dkr.ecr.us-east-1.amazonaws.com/osaf-batch-runner:3.11.0
```

**If docker login fails with `400 Bad Request` / `no basic auth credentials`**:
Windows PowerShell 5.1 mangles the piped password. Run the same two commands in
Git Bash or cmd.exe instead — they pipe raw bytes and work.

Verify in the console: ECR → osaf-batch-runner → the `3.11.0` tag is listed.

## 4. Run an analysis

```powershell
# start the local server (no Docker/Redis/R needed) and submit with LHS +
# external batch execution:
ruby bin/openstudio_meta start_local --worker-number 1 ./my_project
ruby bin/openstudio_meta run_analysis -a lhs --batch-run-method external_batch_run my_analysis.json http://localhost:8080
# -> server samples (pure-Ruby LHS) and packages to
#    <my_project>/temp_data/external_batch/analysis_<id>/

# push the package + submit the array job:
ruby external_batch/aws/submit_batch.rb <my_project>/temp_data/external_batch/analysis_<id> `
    --bucket osaf-batch-<ACCOUNT> --job-queue osaf-batch-queue --job-definition osaf-batch-runner --region us-east-1

# mirror results down (leave running; exits when all chunks are done):
ruby external_batch/aws/sync_results.rb <my_project>/temp_data/external_batch/analysis_<id> `
    --s3-uri s3://osaf-batch-<ACCOUNT>/runs/analysis_<id> --region us-east-1
```

The server ingests results as they land; watch analysis progress in the normal
server UI (http://localhost:8080).

## 5. What to watch in the AWS console while it runs

Set the console's region picker (top right) to your region first — resources
are invisible in the wrong region.

1. **Batch → Jobs** (pick job queue `osaf-batch-queue`): your job appears with
   status; click it → array children (one per chunk). Normal lifecycle:
   `SUBMITTED → RUNNABLE → STARTING → RUNNING → SUCCEEDED`.
   - `RUNNABLE` for 3–8 min at the start is NORMAL: the fleet is scaling from
     zero and pulling the ~3 GB image. Be patient before debugging.
   - Click a child job → **Log stream name** link → CloudWatch Logs shows the
     container's live stdout (the task_wrapper + runner output). This is THE
     debugging view.
2. **Batch → Compute environments** → `osaf-batch-ce`: status should be VALID;
   "Desired vCPUs" jumps up when jobs queue and returns to 0 after.
3. **EC2 → Instances**: the m5d/m6idn instances Batch launched; they terminate
   automatically a few minutes after the queue drains. If instances linger >15
   min with nothing queued, something is wrong — check the compute environment.
4. **S3 → your bucket → runs/analysis_<id>/**: `package/` appears at submit;
   `results/<dp_id>/` folders appear as sims finish; `chunk_<i>.done` markers
   mean a chunk completed.
5. **CloudWatch → Log groups → /aws/batch/job**: all container logs, kept after
   jobs finish.
6. **Billing → Cost Explorer** (search "Billing"): EC2 + S3 charges show within
   a day. A small smoke run is cents. Set up a **Budget alert** (Billing →
   Budgets → e.g. $10/month) on any personal account — best practice.

## 6. Stuck/failing? (in likelihood order)

- Child job stuck `RUNNABLE` > 10 min: Compute environment INVALID (Batch →
  compute env → status reason), no default VPC/subnets, or vCPU quota
  (Service Quotas → EC2 → "Running On-Demand Standard instances" — new accounts
  sometimes need an increase).
- Child job `FAILED` immediately: click it → status reason. `CannotPullContainer`
  = image tag/ECR wrong; `AccessDenied` in logs = task role/bucket mismatch.
- Job SUCCEEDED but no results locally: is `sync_results.rb` running? Right
  `--s3-uri`? Check S3 in the console — if `results/` is populated there, the
  problem is only the sync-down.
- Corporate proxy TLS errors from the CLI: add `ca_bundle = <corp cert path>`
  under `[default]` in `~/.aws/config`.

## 7. Cleanup

- Between runs: nothing to do — the compute environment scales to zero
  (you pay only S3 storage; `runs/` auto-expires after 30 days).
- Remove everything: `cd external_batch/aws/infra && terraform destroy` (empty
  the S3 bucket first if destroy complains it's not empty:
  `aws s3 rm s3://osaf-batch-<ACCOUNT>/runs --recursive`).
