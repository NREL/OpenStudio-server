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

      config {
        command = "/opt/nomad/task_wrapper.sh"
        # We'll use a loop inside the task wrapper or modify it to handle multiple chunks
        # For simplicity in this example, we'll pass the total chunks and let the wrapper handle distribution
        args = [
          "--package-uri", "{{PACKAGE_URI}}",
          "--results-uri", "{{RESULTS_URI}}",
          "--total-chunks", "{{NUM_CHUNKS}}",
          "--openstudio-cmd", "openstudio"
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