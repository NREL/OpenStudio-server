# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# External batch execution: package an analysis's datapoints to a directory,
# have an external executor (local mock, Kestrel/SLURM array via Apptainer, or
# AWS Batch array job) run them with the OpenStudio CLI, and ingest the results
# back into Mongo. See external_batch/README.md at the repo root for the runner,
# executors, and contracts.
module ExternalBatch
  # Version of the package/results contract. The runner refuses to process a
  # manifest with a different schema_version.
  SCHEMA_VERSION = 1

  def self.root_dir
    # Handle potential nil from ENV and provide fallback
    env_root = ENV['OS_SERVER_EXTERNAL_BATCH_ROOT']
    if env_root.nil? || env_root.empty?
      # Handle potential undefined APP_CONFIG
      if defined?(APP_CONFIG) && APP_CONFIG
        sim_root_path = APP_CONFIG['sim_root_path']
      else
        # Fallback to a reasonable default if APP_CONFIG is not available
        sim_root_path = Dir.tmpdir  # Use system temp directory as fallback
      end
      root = File.join(sim_root_path, 'external_batch')
    else
      root = env_root
    end
    # expand_path normalizes Windows backslashes, which would otherwise act as
    # escape characters in the ingester's Dir[] globs
    File.expand_path(root)
  end

  def self.batch_dir(analysis_id)
    File.join(root_dir, "analysis_#{analysis_id}")
  end

  # Written by the server (Packager), consumed by the executor/runner.
  def self.package_dir(analysis_id)
    File.join(batch_dir(analysis_id), 'package')
  end

  # Written by the runner, consumed by the server (Ingester).
  def self.results_dir(analysis_id)
    File.join(batch_dir(analysis_id), 'results')
  end

  def self.manifest_path(analysis_id)
    File.join(package_dir(analysis_id), 'manifest.json')
  end
end
