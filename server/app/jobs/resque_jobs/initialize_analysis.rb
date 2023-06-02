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
    # todo error handling
    # todo handle cleanup if this fails
    def self.perform(analysis_type, analysis_id, job_id, options = {})
      # TODO: error handling and logging around looking up analysis and detecting start/complete
      analysis = Analysis.find(analysis_id)
      # this will handle unzipping to osdata volume and running any initialization scripts
      analysis.run_initialization
    end

    # after_perform hooks only called if job completes successfully
    def self.after_perform_run_analysis(analysis_type, analysis_id, job_id, options = {})
      # enqueue for run
      Resque.enqueue(RunAnalysis, analysis_type, analysis_id, job_id, options)
    end
  end
end
