# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module ResqueJobs
  class DeleteAnalysis
    @queue = :background

    def self.perform(analysis_directory)
      job = DjJobs::DeleteAnalysis.new(analysis_directory)
      job.perform
    end
  end
end
