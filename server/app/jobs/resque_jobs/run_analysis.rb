# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'json' # Require JSON for serialization
# Runs on background node.  Wraps older DJ code to work w/Resque
module ResqueJobs
  class RunAnalysis
    @queue = :analyses

    # before_perform hook to check if the conditions are met
    def self.before_perform_check_dependencies(analysis_type, analysis_id, job_id, options = {})
      Resque.logger.debug "RUNANALYSIS BEFORE_PERFORM_CHECK_CONDITIONS: #{analysis_id}, #{analysis_type}, #{job_id}, #{options}"

      if analysis_type == 'batch_run'
        dependencies_met = dependencies_completed(analysis_id)
        unless dependencies_met
          # If dependencies are not met, re-enqueue the job with a delay
          sleep 5
          Resque.enqueue(self, analysis_type, analysis_id, job_id, options)
          raise Resque::Job::DontPerform
        end
      end
    end
    
    def self.dependencies_completed(analysis_id)
      Resque.logger.debug "RUNANALYSIS DEPENDENCIES_COMPLETED: #{analysis_id}"
      # Check if there's a completed mark for any analysis type with the given analysis_id
      completed = Resque.redis.exists?("analysis:#{analysis_id}:completed")
      completed
    end
    
    def self.perform(analysis_type, analysis_id, job_id, options = {})
      Resque.logger.debug "RUNANALYSIS PERFORM: #{analysis_type} :#{analysis_id}"
      job = "AnalysisLibrary::#{analysis_type.camelize}".constantize.new(analysis_id, job_id, options)
      job.perform
    end

    def self.after_perform_mark_completion(analysis_type, analysis_id, job_id, options = {})
      Resque.logger.debug "RUNANALYSIS AFTER_PERFORM_MARK_COMPLETION: #{analysis_type} :#{analysis_id}"
      # Mark this job type as completed for the given analysis_id
      Resque.redis.set("analysis:#{analysis_id}:completed", true)
      # Continue with any additional after_perform actions, such as enqueueing dependent jobs or cleanup
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
