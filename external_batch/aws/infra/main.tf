# One-time AWS infrastructure for external batch runs (run `terraform apply` once).
# Creates: S3 bucket (the transport hub), ECR repo (runner image), AWS Batch
# compute environment + job queue + job definition, and least-privilege IAM.
#
# Design notes (from doc/external_batch_plan.md prior-art review):
# - ON-DEMAND instances (not spot) by default; BEST_FIT_PROGRESSIVE allocation.
# - m6idn/m5d families: the local NVMe keeps EnergyPlus small-file I/O off EBS.
# - 1 vCPU + ~8 GB per container: one sim at a time per array task; array size
#   (= number of chunks) is the parallelism knob.
# - Workers get an IAM TASK ROLE scoped to this bucket's runs/ prefix — no AWS
#   keys ever enter a container.
# - MIN_VCPUS = 0: the fleet scales to zero between analyses.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ------------------------------------------------------------------ variables

variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "osaf-batch"
}

variable "bucket_name" {
  description = "S3 bucket for batch packages/results (must be globally unique)"
  type        = string
}

variable "max_vcpus" {
  description = "Compute environment ceiling (1 vCPU = 1 concurrent simulation)"
  type        = number
  default     = 256
}

variable "container_memory_mb" {
  description = "Memory per array task (one sim; ~8 GB rule of thumb, 7500 packs cleanly)"
  type        = number
  default     = 7500
}

variable "runner_image_tag" {
  description = "Tag of the runner image in the ECR repo (e.g. the OpenStudio version)"
  type        = string
  default     = "3.11.0"
}

variable "results_expire_days" {
  description = "Days before runs/ objects auto-expire in S3 (0 = keep forever)"
  type        = number
  default     = 30
}

variable "subnet_ids" {
  description = "Subnets for the compute environment (default: default VPC subnets)"
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC for the compute environment security group (default: default VPC)"
  type        = string
  default     = ""
}

# ------------------------------------------------------- default VPC fallback

data "aws_vpc" "default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

locals {
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
}

data "aws_subnets" "default" {
  count = length(var.subnet_ids) == 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

locals {
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.default[0].ids
}

# ------------------------------------------------------------------------- S3

resource "aws_s3_bucket" "batch" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "batch" {
  bucket                  = aws_s3_bucket.batch.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "batch" {
  count  = var.results_expire_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.batch.id
  rule {
    id     = "expire-runs"
    status = "Enabled"
    filter {
      prefix = "runs/"
    }
    expiration {
      days = var.results_expire_days
    }
  }
}

# ------------------------------------------------------------------------ ECR

resource "aws_ecr_repository" "runner" {
  name                 = "${var.name_prefix}-runner"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# ------------------------------------------------------------------------ IAM
# Three-role topology; each scoped to exactly what that plane needs.

# 1. Batch service role (lets AWS Batch manage EC2/ECS on our behalf)
resource "aws_iam_role" "batch_service" {
  name = "${var.name_prefix}-service-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "batch.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "batch_service" {
  role       = aws_iam_role.batch_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# 2. ECS instance role (the EC2 hosts; pulls images, joins the ECS cluster)
resource "aws_iam_role" "ecs_instance" {
  name = "${var.name_prefix}-instance-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

# 3. Task role (what the runner containers can do: the run bucket, nothing else)
resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-task-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "task_s3" {
  name = "${var.name_prefix}-task-s3"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.batch.arn
        Condition = { StringLike = { "s3:prefix" = "runs/*" } }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.batch.arn}/runs/*"
      }
    ]
  })
}

# ---------------------------------------------------------------------- Batch

resource "aws_security_group" "batch" {
  name        = "${var.name_prefix}-sg"
  description = "OSAF external batch compute (egress only)"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_batch_compute_environment" "batch" {
  compute_environment_name = "${var.name_prefix}-ce"
  type                     = "MANAGED"
  service_role             = aws_iam_role.batch_service.arn
  depends_on               = [aws_iam_role_policy_attachment.batch_service]

  compute_resources {
    type                = "EC2" # on-demand; switch to SPOT deliberately, not by default
    allocation_strategy = "BEST_FIT_PROGRESSIVE"
    instance_role       = aws_iam_instance_profile.ecs_instance.arn
    instance_type       = ["m6idn", "m5d"] # d = local NVMe for E+ small-file I/O
    min_vcpus           = 0
    max_vcpus           = var.max_vcpus
    security_group_ids  = [aws_security_group.batch.id]
    subnets             = local.subnet_ids
  }
}

resource "aws_batch_job_queue" "batch" {
  name     = "${var.name_prefix}-queue"
  state    = "ENABLED"
  priority = 1
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.batch.arn
  }
}

resource "aws_batch_job_definition" "runner" {
  name                  = "${var.name_prefix}-runner"
  type                  = "container"
  platform_capabilities = ["EC2"]

  retry_strategy {
    attempts = 2 # chunk re-runs are idempotent (ingester skips completed dps)
  }

  container_properties = jsonencode({
    image      = "${aws_ecr_repository.runner.repository_url}:${var.runner_image_tag}"
    jobRoleArn = aws_iam_role.task.arn
    resourceRequirements = [
      { type = "VCPU", value = "1" },
      { type = "MEMORY", value = tostring(var.container_memory_mb) }
    ]
    environment = [
      # BATCH_S3_URI is supplied per-run via submit-time container overrides
      { name = "BATCH_S3_URI", value = "" }
    ]
  })
}

# -------------------------------------------------------------------- outputs

output "bucket_name" {
  value = aws_s3_bucket.batch.bucket
}

output "ecr_repository_url" {
  value = aws_ecr_repository.runner.repository_url
}

output "job_queue" {
  value = aws_batch_job_queue.batch.name
}

output "job_definition" {
  value = aws_batch_job_definition.runner.name
}

output "region" {
  value = var.region
}
