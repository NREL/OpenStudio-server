# AWS Batch smoke test — exact reproduction runbook (this machine)

Every command actually used for the first successful real-AWS run, 2026-07-02,
branch `external_batch`. Account <ACCOUNT_ID>, region us-east-1, bucket
`osaf-batch-<ACCOUNT_ID>`. Generic user docs: `external_batch/aws/WALKTHROUGH.md`
and `external_batch/aws/README.md`; this file is the warts-and-all local record.

## One-time setup

```powershell
winget install --id Amazon.AWSCLI -e --accept-source-agreements --accept-package-agreements
winget install --id Hashicorp.Terraform -e --accept-source-agreements --accept-package-agreements
# open a NEW terminal afterward (PATH), or in-session:
#   $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
```

Console: created access key (root user — switch to an IAM user later), then in
a private terminal: `aws configure` (us-east-1, json). Verify:
```powershell
aws sts get-caller-identity
```

```powershell
cd C:\projects\OS-Server-develop\external_batch\aws\infra
terraform init
# FIRST APPLY FAILED: "no matching EC2 VPC found" -> account had no default VPC:
aws ec2 create-default-vpc --region us-east-1
terraform apply -auto-approve -var region=us-east-1 -var bucket_name=osaf-batch-<ACCOUNT_ID>
# outputs: bucket osaf-batch-<ACCOUNT_ID>, ecr <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/osaf-batch-runner,
#          queue osaf-batch-queue, jobdef osaf-batch-runner
```

Image build + push (login MUST be from Git Bash/cmd — PowerShell 5.1 pipe broke
`--password-stdin` with `400 Bad Request`):
```bash
cd /c/projects/OS-Server-develop/external_batch
'/c/Program Files/Amazon/AWSCLIV2/aws.exe' ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
docker build -f aws/Dockerfile --build-arg OPENSTUDIO_VERSION=3.10.0 \
  -t <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/osaf-batch-runner:3.10.0 .
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/osaf-batch-runner:3.10.0
```

## Server side (spec-harness variant — no meta-CLI gem build needed)

The production path is `openstudio_meta start_local` + `run_analysis
--batch-run-method external_batch_run`. For the smoke we drove the same
server-side code via the rails test env (this checkout's bundle + a throwaway
mongod). Machine gotcha: `server/.bundle/config` pins
`BUNDLE_WITHOUT=development:test`, so point `BUNDLE_APP_CONFIG` at an empty dir.

```bash
mongod --port 27099 --dbpath <scratch>/db --logpath <scratch>/logs/mongod.log &

cd /c/projects/OS-Server-develop/server
export BUNDLE_APP_CONFIG=<empty dir>
export RAILS_ENV=local-test OS_SERVER_MONGO_PORT=27099 OS_SERVER_DATABASE_NAME=os_aws_smoke
export OS_SERVER_PROJECT_PATH=<scratch>/proj OS_SERVER_RAILS_TMP_PATH=<scratch>/tmp
export OS_SERVER_LOG_PATH=<scratch>/logs OS_SERVER_HOST_URL=http://localhost:8080
export OS_SERVER_EXTERNAL_BATCH_ROOT=<scratch>/batch

# create fixture analysis (spec/files/batch_datapoints/example_csv.{json,zip}),
# Ruby-LHS sample (4 samples -> 2 unique dps), package, queue dps:
bundle exec rails runner <scratch>/smoke_setup.rb
# smoke_setup.rb = fixture load + problem.algorithm{number_of_samples:4,
#   sample_method:all_variables, sampling_backend:ruby, seed:2026} +
#   run_analysis(true,'lhs','analysis_type'=>'lhs') +
#   ExternalBatch::Packager.new(a,dps,dps_per_chunk:1).package! + set_queued_state
# -> ANALYSIS_ID=5b7d47ca-9cb5-4173-b80b-baa07f60ab42, CHUNKS=2
```

## Submit + retrieve

```bash
cd /c/projects/OS-Server-develop
ruby external_batch/aws/submit_batch.rb "<batch_dir>" \
  --bucket osaf-batch-<ACCOUNT_ID> --job-queue osaf-batch-queue \
  --job-definition osaf-batch-runner --region us-east-1 \
  --aws-cmd '"C:\Program Files\Amazon\AWSCLIV2\aws.exe"'
# -> array job size=2, jobId 21b87f17-563f-4feb-973c-c53adfc8afe7

ruby external_batch/aws/sync_results.rb "<batch_dir>" \
  --s3-uri s3://osaf-batch-<ACCOUNT_ID>/runs/analysis_5b7d47ca-9cb5-4173-b80b-baa07f60ab42 \
  --region us-east-1 --interval 30 \
  --aws-cmd '"C:\Program Files\Amazon\AWSCLIV2\aws.exe"'
# exits when chunk_0.done + chunk_1.done have arrived
```

Progress checks used while waiting:
```bash
aws batch describe-jobs --jobs <jobId> --region us-east-1 \
  --query 'jobs[0].arrayProperties.statusSummary'
aws batch describe-compute-environments --compute-environments osaf-batch-ce \
  --region us-east-1 --query 'computeEnvironments[0].{status:status,desired:computeResources.desiredvCpus}'
aws ec2 describe-instances --region us-east-1 \
  --filters Name=instance-state-name,Values=pending,running \
  --query 'Reservations[].Instances[].{type:InstanceType,state:State.Name}'
```
Observed timeline: RUNNABLE ~4 min (fleet scale-up from 0, m5d.xlarge launched,
3 GB image pull), then RUNNING ~ a few min per sim.

## Ingest + verify

```bash
# same env as server side above:
bundle exec rails runner <scratch>/smoke_ingest.rb
# = ExternalBatch::Ingester.new(analysis).ingest_new_results + print dp status/results
```

## Gotchas hit (in order)

1. Windows Store stub `aws.rb` on PATH is NOT the AWS CLI; real one at
   `C:\Program Files\Amazon\AWSCLIV2\aws.exe`.
2. `terraform` needs a fresh shell (or manual PATH reload) after winget.
3. Account had NO default VPC in us-east-1 → `aws ec2 create-default-vpc`.
4. `aws ecr get-login-password | docker login --password-stdin` fails from
   PowerShell 5.1 (400 Bad Request) → run from Git Bash or cmd.
5. `BUNDLE_WITHOUT=development:test` in server/.bundle/config → BUNDLE_APP_CONFIG override.
6. LHS 4 samples on 2 discrete vars deduped to 2 datapoints (samples.uniq) —
   expected; use continuous vars for exact-n datapoints.
7. Backslash Windows path in OS_SERVER_EXTERNAL_BATCH_ROOT broke the ingester's
   reports Dir[] glob (backslash = glob escape char) → eplustbl.html not
   attached on first ingest. FIXED: ExternalBatch.root_dir now File.expand_path
   normalizes; spec exercises native separators.

## Outcome (2026-07-02)

- Array job 21b87f17, 2 tasks on one m5d.xlarge; RUNNABLE ~4 min (scale-from-zero
  + image pull), sims ~12 s each (small fixture model), results in S3 ~90 s later.
- Both dps ingested `completed / completed normal`; LHS-sampled values propagated
  into measure results (cooling_adjustment 1.0 vs 2.0 matching set_variable_values).
- Full artifact round-trip: data_point.zip (560K), eplustbl.html, in.osm,
  measure_attributes.json, out.osw, logs.
- Cost: a few minutes of one m5d.xlarge + S3 pennies.

## Smoke test 2 — SEB calibration LHS (algo-spec fixture, golden-value verified)

Same pipeline, real workflow: `spec/files/SEB_LHS_2013_discrete.json` + `.zip`
(the docker_stack_algo_spec `:lhs_discrete` project — SEB model, annual E+ run,
`calibration_reports_enhanced_20` objective functions vs utility bills).

- Setup script `smoke2_setup.rb` (same env as smoke 1): loads the fixture,
  **regenerates blank variable uuids** (the OSA gem does this client-side via
  `reset_uuids: true`; direct DB seeding must replicate it or
  `Measure.create_from_os_json` collides on `_id: ""`), keeps the fixture's
  algorithm (individual_variables, n=1, seed 1973) + `sampling_backend: 'ruby'`,
  runs LHS inline, packages `dps_per_chunk: 1` → 3 dps / 3 chunks.
- Submit/sync identical to smoke 1 (array size=3, jobId 420b5399…). All 3 tasks
  SUCCEEDED in one scale-up wave.
- Verify `smoke2_verify.rb`: ingests, then applies the SAME check as the CI
  spec — slice the 4 calibration metrics, truncate(2), assert membership in the
  spec's golden list. RESULT: all 3 dps `completed normal`, objectives.json
  attached, and metrics matched golden rows exactly:
  - measure-off dp → 37.79 / -38.65 / 206.55 / -166.22 (golden row 4)
  - other two dps → 37.41 / -38.26 / 206.57 / -166.23 (golden row 5)
  i.e. AWS-executed results are value-identical to the classic docker/R CI path.
- Gotchas: (8) fixture workflow variables carry `uuid: ""` → regenerate before
  direct seeding (production path unaffected); (9) `dp.results` returns
  BSON::Document — string keys survive `deep_symbolize_keys`; normalize with
  `.to_h.transform_keys(&:to_sym)` before comparing to symbol-keyed hashes.

## Official spec + billing (added later on 2026-07-02)

- The whole smoke-2 flow is now a committed, user-runnable spec:
  `server/spec/features/aws_batch_smoke_spec.rb` — self-skips unless
  AWS_BATCH_SMOKE_{BUCKET,JOB_QUEUE,JOB_DEFINITION} set (+ optional _REGION,
  _AWS_CMD). Validated against real AWS: 1 example 0 failures in 4m24s, golden
  values matched. Mocked CI twin (no AWS): spec/models/external_batch_aws_spec.rb.
- Budget alert created on the account via CLI (osaf-batch-monthly, $10/month,
  email at 80% actual + 100% forecast). Command + console steps in
  WALKTHROUGH.md §7. Batch GUI shows NO cost — use Cost Explorer grouped by
  service (~24 h lag) or job runtime × instance price for per-run math.

## Cleanup

Compute scales to zero by itself; S3 `runs/` expires after 30 days. Full
teardown: `aws s3 rm s3://osaf-batch-<ACCOUNT_ID>/runs --recursive` then
`terraform destroy` in external_batch/aws/infra.
