# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Wrap the RunSimulateDataPoint job for use in Resque/Redis
module ResqueJobs
  class RunSimulateDataPoint
    @queue = :simulations

    def self.after_enqueue(data_point_id, options = {})
      d = DataPoint.find(data_point_id)
      d.set_queued_state
      d.add_to_rails_log("DataPoint #{data_point_id} enqueued for processing.")
    end

    def self.perform(data_point_id, options = {})
      d = DataPoint.find(data_point_id)
      statuses = d.get_statuses
      # A DP can be requeued when a worker is getting shutdown as a spot instance.
      # When that happens the status gets changed from ':started' to ':queued' but the resque job is still processing on the worker until it is killed.
      # There is a case where that worker completes a successful job, before the requeued DP starts.
      # In that case, we should skip re-running that DP because it was both completed and completed normal already.
      # If its a requeued failed job, then that should still get re-run
      #
      # A job can also sit on the :simulations/:requeued Resque list for a long time (worker
      # backlog, HPA scale-down, etc). If the owning analysis was explicitly stopped in the
      # meantime (Analysis#stop_analysis/#soft_stop_analysis, e.g. ops quarantining a batch with
      # a permanently corrupt seed zip), run_flag is false and this stale payload must not
      # dispatch a fresh worker download/extract against it - that just recreates the same
      # failure or deadlock the stop was meant to end.
      # run_flag defaults to false and only flips true when the analysis is started, so
      # run_flag alone cannot distinguish "ops stopped this analysis" from "nobody has
      # started it yet" - and datapoints CAN legitimately be submitted against a
      # never-started analysis (batch datapoint upload + direct submit_simulation).
      # start_time comes from the analysis' jobs, which exist iff it was started.
      analysis_stopped = d.analysis.run_flag == false && !d.analysis.start_time.nil?
      if analysis_stopped
        msg = "SKIPPING #{data_point_id} because analysis #{d.analysis_id} has run_flag=false (analysis was stopped)"
        d.add_to_rails_log(msg)
        puts msg
      elsif !(statuses[:status] == 'completed' && statuses[:status_message] == 'completed normal')
        msg = "RUNNING DJ: #{statuses[:status]} and #{statuses[:status_message]}"
        d.add_to_rails_log(msg)
        puts msg
        job = DjJobs::RunSimulateDataPoint.new(data_point_id, options)
        job.perform
      else
        msg = "SKIPPING #{data_point_id} since it is #{statuses[:status]} and #{statuses[:status_message]}"
        d.add_to_rails_log(msg)
        puts msg
      end 
    rescue SignalException, Errno::ENOSPC, Resque::DirtyExit, Resque::TermException, Resque::PruneDeadWorkerDirtyExit => e
      # Log the termination and re-enqueue attempt. d is nil when DataPoint.find above
      # raised (e.g. the datapoint was deleted), so guard it - otherwise the rescue itself
      # crashes with NoMethodError and masks the real error, leaving a non-retryable job.
      msg = "Worker Caught Exception: #{e.inspect}"#: Re-enqueueing DataPoint ID #{data_point_id}")
      d.nil? ? Rails.logger.warn(msg) : d.add_to_rails_log(msg)
      #Resque.enqueue_to(:requeued, self, data_point_id, options)
      #puts "DataPoint #{data_point_id} re-enqueued."
      puts msg
    rescue => e
      msg = "Worker Caught Unhandled Exception: #{e.message}"#: Re-enqueueing DataPoint ID #{data_point_id}")
      d.nil? ? Rails.logger.warn(msg) : d.add_to_rails_log(msg)
      #Resque.enqueue_to(:requeued, self, data_point_id, options)
      #puts "Unhandled exception, re-enqueued DataPoint."
      puts msg
    end
  end
end
