# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module DjJobs
  # Delete the files on the server
  DeleteAnalysis = Struct.new(:analysis_directory) do
    def perform
      FileUtils.rm_rf analysis_directory if Dir.exist? analysis_directory
    end

    def queue_name
      'background'
    end
  end
end
