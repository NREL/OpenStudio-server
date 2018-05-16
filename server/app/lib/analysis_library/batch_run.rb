# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# Run a batch of simulations using the local queue.
class AnalysisLibrary::BatchRun < AnalysisLibrary::Base
  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = ActiveSupport::HashWithIndifferentAccess.new(
        {
            skip_init: false,
            data_points: [],
            run_data_point_filename: 'run_openstudio.rb',
            problem: {}
        }
    )
    @options = defaults.deep_merge(options)

    @analysis_id = analysis_id
    @analysis_job_id = analysis_job_id
  end

  # Perform is the main method that is run in the background.  At the moment if
  # this method crashes it will be logged as a failed delayed_job and will fail
  # after max_attempts.
  def perform
    @analysis = Analysis.find(@analysis_id)

    # get the analysis and report that it is running
    @analysis_job = AnalysisLibrary::Core.initialize_analysis_job(@analysis, @analysis_job_id, @options)

    # reload the object (which is required) because the subdocuments (jobs) may have changed
    @analysis.reload

    ids = []
    if @options[:data_points].empty?
      logger.info 'No datapoints were passed into the options, therefore checking which datapoints to run'

      # queue up the simulations
      @analysis.data_points.where(status: 'na').each do |dp|
        logger.info "Adding #{dp.uuid} to simulations queue"
        ids << dp.id if dp.submit_simulation
      end
    end

    logger.info "Background job ids are: #{ids}"

    # Watch the delayed jobs to see when all the datapoints are completed.
    # I would really prefer making a chord or callback for this.
    until @analysis.data_points.where(:_id.in => ids, :status.ne => 'completed').count == 0
      logger.info 'waiting'
      sleep 5
    end
  rescue => e
    log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
    logger.error log_message
    @analysis.status_message = log_message
    @analysis.save!
  ensure
    require_relative "gather_results"
    zip_all_results(@analysis_id, 1)
    logger.info 'Finished running batchrun method'
    @analysis_job.end_time = Time.now
    @analysis_job.status = 'completed'
    @analysis_job.save!
    @analysis.reload
    @analysis.save!
  end
end
