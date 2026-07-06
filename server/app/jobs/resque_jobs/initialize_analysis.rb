# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************
# Runs on web node
module ResqueJobs
  class InitializeAnalysis
    @queue = :analysis_wrappers

    # Perform set up before running an analysis
    # this is enqueued in Analysis#start.
    def self.perform(analysis_type, analysis_id, job_id, options = {})
      # TODO: error handling and logging around looking up analysis and detecting start/complete
      analysis = Analysis.find(analysis_id)
      # this will handle unzipping to osdata volume and running any initialization scripts
      analysis.run_initialization
    rescue StandardError => e
      # Mark the analysis failed so it reaches a terminal state visible to clients instead
      # of sitting in 'queued' forever, then re-raise so Resque records the failed job (issue #841).
      Rails.logger.error "InitializeAnalysis failed for analysis #{analysis_id}: #{e.message}"
      begin
        analysis&.fail_job!("Analysis initialization failed: #{e.message}")
      rescue StandardError => mark_error
        Rails.logger.error "Could not mark analysis #{analysis_id} as failed: #{mark_error.message}"
      end
      raise
    end

    # after_perform hooks only called if job completes successfully
    def self.after_perform_run_analysis(analysis_type, analysis_id, job_id, options = {})
      # enqueue for run
      Resque.enqueue(RunAnalysis, analysis_type, analysis_id, job_id, options)
    end
  end
end
