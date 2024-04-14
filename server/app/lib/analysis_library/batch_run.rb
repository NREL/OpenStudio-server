# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Run a batch of simulations using the local queue.
class AnalysisLibrary::BatchRun < AnalysisLibrary::Base
  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = ActiveSupport::HashWithIndifferentAccess.new(
      skip_init: false,
      data_points: [],
      run_data_point_filename: 'run_openstudio.rb',
      problem: {}
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

    if Rails.application.config.job_manager == :resque
     # Wait loop to ensure all queuing is complete for any analysis
     queuing_keys = Resque.redis.keys("analysis:*:queuing")
      while queuing_keys.any?
        queuing_analyses = queuing_keys.map { |key| key.split(':').second }
        logger.info "#{@analysis_id} is Waiting for the following analyses to finish queuing: #{queuing_analyses.join(', ')}"
        sleep 5
        queuing_keys = Resque.redis.keys("analysis:*:queuing")
      end
    end

    ids = []
    if @options[:data_points].empty?
      logger.info 'No datapoints were passed into the options, therefore checking which datapoints to run'
      
      if Rails.application.config.job_manager == :resque
        # Set Redis flag to indicate queuing is starting
        logger.info "Setting Redis queuing flag for #{@analysis_id}"
        Resque.redis.set("analysis:#{@analysis_id}:queuing", true)
      end

      # queue up the simulations
      @analysis.data_points.where(status: 'na').each do |dp|
        logger.info "Adding #{dp.uuid} to simulations queue"
        ids << dp.id if dp.submit_simulation
      end
      
      if Rails.application.config.job_manager == :resque
        # Delete Redis flag after queuing is done
        logger.info "Deleting Redis queuing flag for #{@analysis_id}"
        Resque.redis.del("analysis:#{@analysis_id}:queuing")
      end        
    end
    # This can be a very long list, so put in .debug
    logger.debug "Background job ids are: #{ids}"

    # Watch the delayed jobs to see when all the datapoints are completed.
    # I would really prefer making a chord or callback for this.
    until @analysis.data_points.where(:_id.in => ids, :status.ne => 'completed').count == 0
      logger.info "waiting for this batch_run simulations to complete: #{@analysis_id}"
      sleep 5
    end
  rescue StandardError => e
    log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
    logger.error log_message
    @analysis.status_message = log_message
    @analysis.save!
  ensure
    logger.info 'Finished running batchrun method'
    @analysis_job.end_time = Time.now
    @analysis_job.status = 'completed'
    @analysis_job.save!
    @analysis.reload
    @analysis.save!
  end
end
