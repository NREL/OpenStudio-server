# Nomad Job Template for External Batch - Array Job Approach
# This follows the standard Nomad pattern for array-like job execution
# Each task in the group processes one chunk

job "{{JOB_NAME}}" {
  type        = "batch"
  datacenters = ["dc1"]
  namespace   = "default"

  group "chunk_processors" {
    # This creates NUM_CHUNKS instances of the task group
    # Each instance gets a unique index from 0 to NUM_CHUNKS-1
    count = {{NUM_CHUNKS}}

    task "run_chunk" {
      driver = "raw_exec"

      # Only run on dedicated client nodes (not the NFS/gateway server)
      constraint {
        attribute = "${node.unique.name}"
        operator  = "regexp"
        value     = "^nomad-client"
      }

      config {
        command = "/usr/local/bin/task_wrapper.sh"
        args = [
          "--package-uri", "{{PACKAGE_URI}}",
          "--results-uri", "{{RESULTS_URI}}",
          "--openstudio-cmd", "openstudio"
        ]
      }

      env {
        PACKAGE_TYPE = "nfsmount"
        RESULTS_TYPE = "nfsmount"
      }

      # Per-task resources — each task runs one OpenStudio/EnergyPlus
      # simulation (one "chunk" / data point).
      #
      # Tuning guidance:
      #   - EnergyPlus is primarily single-threaded; 2000 MHz ≈ 1 vCPU
      #   - Total concurrent sims per client = client_vCPUs / (cpu/1000)
      #   - Bump cpu/memory for complex models (large envelope, EMS,
      #     HVAC sizing runs). Monitor swap / OOM on the clients.
      #
      # Example: CM.Medium client (16 vCPU, 32 GB RAM) with these values
      # can run ~8 sims concurrently (16 / (2000/1000) = 8), using ~32 GB
      # of the 32 GB available — tight. Use CM.2Medium or reduce memory.
      resources {
        cpu    = 2000 # MHz — ~1 vCPU at modern clock speeds
        memory = 4096 # MB  — 4 GB, comfortable for medium models
        disk   = 1000 # MB  — scratch space for extraction + logs

        # ── Resource limits (soft) vs reservations (hard) ──────────
        # Uncomment to let Nomad oversubscribe the CPU when other
        # tasks are idle, while guaranteeing a minimum:
        # cpu {
        #   reserved = 2000   # guaranteed MHz
        #   max      = 4000   # burst to 2 vCPUs if idle cycles exist
        # }
        # memory {
        #   reserved = 4096   # guaranteed MB
        #   max      = 6144   # burst to 6 GB if available
        # }
      }

      # Optional: Add constraints to run on specific nodes or classes
      # constraint {
      #   attribute = "${attr.cpu.architecture}"
      #   value     = "amd64"
      # }

      # Optional: Configure restart policy
      # restart {
      #   attempts = 2
      #   interval = "5m"
      #   delay    = "25s"
      #   mode     = "delay"
      # }

      # Optional: Add health checks
      # check {
      #   type     = "script"
      #   path     = "/local/healthcheck.sh"
      #   interval = "30s"
      #   timeout  = "2s"
      # }
    }
  }
}
