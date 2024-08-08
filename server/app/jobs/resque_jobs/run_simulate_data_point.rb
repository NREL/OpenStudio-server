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
      if !(statuses[:status] == 'completed' && statuses[:status_message] == 'completed normal')
        msg = "RUNNING DJ: #{statuses[:status]} and #{statuses[:status_message]}"
        d.add_to_rails_log(msg)
        job = DjJobs::RunSimulateDataPoint.new(data_point_id, options)
        job.perform
      else
        msg = "SKIPPING #{data_point_id} since it is #{statuses[:status]} and #{statuses[:status_message]}"
        d.add_to_rails_log(msg)
      end 
    rescue Errno::ENOSPC, Resque::DirtyExit, Resque::TermException, Resque::PruneDeadWorkerDirtyExit => e
      # Log the termination and re-enqueue attempt
      d.add_to_rails_log("Worker Caught Exception: #{e.inspect}: Re-enqueueing DataPoint ID #{data_point_id}")
      Resque.enqueue(self, data_point_id, options)
      d.add_to_rails_log("DataPoint #{data_point_id} re-enqueued.")
    rescue => e
      d.add_to_rails_log("Worker Caught Unhandled Exception: #{e.message}: Re-enqueueing DataPoint ID #{data_point_id}")
      Resque.enqueue(self, data_point_id, options)
      d.add_to_rails_log("Unhandled exception, re-enqueued DataPoint.")
    end
  end
end
