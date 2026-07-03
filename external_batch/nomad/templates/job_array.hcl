# Nomad Job Template for External Batch - Array Job Approach
# This follows the standard Nomad pattern for array-like job execution
# Each task in the group processes one chunk

job "{{JOB_NAME}}" {
  datacenters = ["dc1"]
  namespace = "{{NAMESPACE}}"

  group "chunk_processors" {
    # This creates NUM_CHUNKS instances of the task group
    # Each instance gets a unique index from 0 to NUM_CHUNKS-1
    count = {{NUM_CHUNKS}}

    task "run_chunk" {
      driver = "exec"

      config {
        command = "/opt/nomad/task_wrapper.sh"
        args = [
          "--package-uri", "{{PACKAGE_URI}}",
          "--results-uri", "{{RESULTS_URI}}",
          "--chunk-index", "${NOMAD_TASK_INDEX}",
          "--openstudio-cmd", "openstudio"
        ]
      }

      env {
        # These would be configured based on your actual storage setup
        PACKAGE_TYPE = "nfsmount"
        RESULTS_TYPE = "nfsmount"
        # For S3, you might set:
        # PACKAGE_TYPE = "s3"
        # RESULTS_TYPE = "s3"
        # And ensure the Nomad task has appropriate AWS/IAM permissions
      }

      resources {
        cpu    = 500   # 500 MHz - adjust based on chunk requirements
        memory = 512   # 512 MB - adjust based on chunk requirements
        disk   = 500   # 500 MB - adjust based on chunk requirements
        
        # For compute-intensive workloads, you might want to reserve specific cores
        # cpu {
        #   reserved = 500
        #   max      = 1000
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