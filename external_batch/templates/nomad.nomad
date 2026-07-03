{{/*
  Nomad Job Template for OpenStudio Batch Processing
  
  This template supports three execution styles:
  1. spread: Task group with count = chunk_count, using spread for distribution
  2. multiprocessor: Single task group with multiprocessor = chunk_count
  3. array: Task group with count = chunk_count (traditional array job)
  
  Recommended: spread or multiprocessor for better Nomad integration
  
  Required variables:
  - analysis_id: Unique identifier for the analysis
  - job_name: Name for the job (optional, defaults to "analysis-{{ .analysis_id }}")
  - namespace: Nomad namespace to run in
  - chunk_count: Number of chunks to process
  - execution_style: One of "spread", "multiprocessor", "array"
  - package_url: URL to download the analysis package artifact
  - cpu_per_chunk: CPU cores required per chunk (will be converted to MHz)
  - memory_per_chunk: Memory required per chunk in MB
  - results_volume_name: Name of the host volume for results (default: "openstudio_results")
*/}}

job "{{ if .job_name }}{{ .job_name }}{{ else }}analysis-{{ .analysis_id }}{{ end }}" {
  namespace = "{{ .namespace }}"

  task_group "chunks" {
    {{ if or (eq .execution_style "spread") (eq .execution_style "array") }}
    count = {{ .chunk_count }}
    {{ else }}
    count = 1
    {{ end }}

    {{ if eq .execution_style "spread" }}
    spread {
      attribute = "${attr.host.unique.name}"
    }
    {{ end }}

    task "process_chunk" {
      driver = "exec"

      config {
        command = "/bin/bash"
        args = [
          "/local/run_chunk.sh"
        ]
      }

      env {
        {{ if eq .execution_style "multiprocessor" }}
        CHUNK_INDEX = "${NOMAD_PROCESS_INDEX}"
        {{ else }}
        CHUNK_INDEX = "${NOMAD_INDEX}"
        {{ end }}

        PACKAGE_PATH = "/local"
        RESULTS_PATH = "/results"
        OPENSTUDIO_CLI_PATH = "/usr/local/bin/openstudio"
        STORAGE_TYPE = "shared_fs"
        # Pass through any additional vars if needed
        {{- with .extra_env }}
        {{- range $key, $value := . }}
        {{$key}} = "{{$value}}"
        {{- end }}
        {{- end }}
      }

      artifact {
        source = "{{ .package_url }}"
        destination = "local"
        extract = true
      }

      volume "results" {
        type = "host"
        source = "{{ if .results_volume_name }}{{ .results_volume_name }}{{ else }}openstudio_results{{ end }}"
        destination = "/results"
        read_only = false
      }

      volume "tmpfs" {
        type = "tmpfs"
        destination = "/tmp_openstudio"
        read_only = false
      }

      resources {
        cpu = {{ mul .cpu_per_chunk 1000 }}
        memory = {{ .memory_per_chunk }}MB
        # Disk reservation for package, results, and temporary files
        # Assuming 2GB for package, 1GB for results, 1GB for temporary files
        disk = 4096
      }
    }
  }
}