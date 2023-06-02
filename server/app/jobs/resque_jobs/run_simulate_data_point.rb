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
    end

    def self.perform(data_point_id, options = {})
      job = DjJobs::RunSimulateDataPoint.new(data_point_id, options)
      job.perform
    end
  end
end
