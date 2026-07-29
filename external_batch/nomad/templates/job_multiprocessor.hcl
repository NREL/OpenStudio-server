# Nomad Job Template for External Batch - Multiprocessor Approach
# Single task group with multiple processors for chunk processing

job "{{JOB_NAME}}" {
  datacenters = ["dc1"]
  namespace = "{{NAMESPACE}}"

  group "chunk_processors" {
    # Process multiple chunks in parallel within this task group
    # Each processor runs one chunk
    count = 1  # Number of task groups
    
    task "run_chunks" {
      driver = "exec"

      # Run as root so we can install tools and write to NFS.
      # In production, use a pre-baked AMI and a non-root user.
      user = "root"

      config {
        command = "/bin/bash"
        args = [
          "-c",
          # Install latest task_wrapper.sh from shared NFS, then run it.
          # This enables painless updates without re-baking client AMIs.
          "cp /nfs/opensstudio/batch/task_wrapper.sh /usr/local/bin/task_wrapper.sh && chmod 755 /usr/local/bin/task_wrapper.sh && /usr/local/bin/task_wrapper.sh --package-uri '{{PACKAGE_URI}}' --results-uri '{{RESULTS_URI}}' --total-chunks '{{NUM_CHUNKS}}' --openstudio-cmd openstudio"
        ]
      }

      env {
        PACKAGE_TYPE = "nfsmount"
        RESULTS_TYPE = "nfsmount"
      }

      resources {
        cpu    = 2000  # 2000 MHz (adjust based on expected parallelism)
        memory = 1024  # 1024 MB
        disk   = 1000  # 1000 MB
      }
    }
  }
}