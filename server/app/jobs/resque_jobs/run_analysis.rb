# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Runs on background node.  Wraps older DJ code to work w/Resque
module ResqueJobs
  class RunAnalysis
    @queue = :analyses

    def self.perform(analysis_type, analysis_id, job_id, options = {})
      job = "AnalysisLibrary::#{analysis_type.camelize}".constantize.new(analysis_id, job_id, options)
      job.perform
    end

    # see https://github.com/resque/resque/blob/master/docs/HOOKS.md
    # after_perform called with job arguments after it performs
    # not called if job fails.
    # note that we are enqueuing regardless of error status; that will need to be checked in FinalizeAnalysis job.
    def self.after_perform_finalize_analysis(analysis_type, analysis_id, job_id, options = {})
      Resque.enqueue(FinalizeAnalysis, analysis_id)
    end
  end
end
