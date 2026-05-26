# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module ResqueJobs
  class ProcessBulkUpload
    @queue = :analyses

    def self.perform(zip_path, project_id)
      job = DjJobs::ProcessBulkUpload.new(zip_path, project_id)
      job.perform
    end
  end
end
