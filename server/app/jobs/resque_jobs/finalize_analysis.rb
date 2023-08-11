# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************
# Runs on web node
module ResqueJobs
  class FinalizeAnalysis
    @queue = :analysis_wrappers

    def self.perform(analysis_id, options = {})
      # TODO: error handling and logging around looking up analysis
      analysis = Analysis.find(analysis_id)
      # TODO: check status of analysis for successful complete:  analysis.status == 'completed'
      analysis.run_finalization
    end
  end
end
