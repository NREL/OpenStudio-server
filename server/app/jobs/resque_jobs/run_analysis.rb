# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Runs on background node.  Wraps older DJ code to work w/Resque
module ResqueJobs
  class RunAnalysis
    @queue = :analyses

    def self.before_perform_assign_started(analysis_type, analysis_id, job_id, options = {})
      Resque.logger.debug "RUNANALYSIS BEFORE_PERFORM_ASSIGN_STARTED: #{analysis_id}, #{analysis_type}, #{job_id}, #{options}"
      if analysis_type != 'batch_run'
        Resque.redis.set("analysis:#{analysis_id}:started", true)
      else
        # give a leading analysis_type (ie, lhs) a chance to start so batch_run doenst start first 
        sleep 5      
      end
    end
    
    def self.after_perform_remove_started(analysis_type, analysis_id, job_id, options = {})
      Resque.logger.debug "RUNANALYSIS AFTER_PERFORM_REMOVE_STARTED: #{analysis_id}, #{analysis_type}, #{job_id}, #{options}"
        if analysis_type != 'batch_run'
          #Resque.redis.set("analysis:#{analysis_id}:#{analysis_type}:completed", true)
          # cleanup the 'started' flag once completed
          Resque.redis.del("analysis:#{analysis_id}:started")
        end  
    end

    # before_perform hook to check if the conditions are met
    def self.before_perform_check_dependencies(analysis_type, analysis_id, job_id, options = {})
      Resque.logger.debug "RUNANALYSIS BEFORE_PERFORM_CHECK_CONDITIONS: #{analysis_id}, #{analysis_type}, #{job_id}, #{options}"

      if analysis_type == 'batch_run'
        dependencies_met = dependencies_completed(analysis_id)
        unless dependencies_met
          # If dependencies are not met, re-enqueue the job with a delay
          sleep 5
          Resque.enqueue(self, analysis_type, analysis_id, job_id, options)
          # this will stop the current job without raising an error, which is good since we just put the job back in the queue
          raise Resque::Job::DontPerform
        end
      end
    end
    
    def self.dependencies_completed(analysis_id)
      Resque.logger.debug "RUNANALYSIS DEPENDENCIES_COMPLETED: #{analysis_id}"
      # Check if there's a started mark for any analysis type with the given analysis_id
      completed = Resque.redis.exists?("analysis:#{analysis_id}:started")
      #return the opposite, since dependencies_completed means there are no started analysis_type jobs with same analysis_id (ie, LHS)
      !completed
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
