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

    if Rails.application.config.x.job_manager == :resque
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
        
        if Rails.application.config.x.job_manager == :resque
          # Set Redis flag to indicate queuing is starting
          logger.info "Setting Redis queuing flag for #{@analysis_id}"
          Resque.redis.set("analysis:#{@analysis_id}:queuing", true)
        end

        # queue up the simulations with throttling to avoid overloading Rserve
        # Submit one analysis at a time with a delay between submissions
        data_points = @analysis.data_points.where(status: 'na')
        total_count = data_points.count
        logger.info "Queuing #{total_count} simulations with throttling"
        
        data_points.each_with_index do |dp, index|
          logger.info "Adding #{dp.uuid} to simulations queue (#{index + 1}/#{total_count})"
          begin
            if dp.submit_simulation
              ids << dp.id
              # Sleep between submissions to avoid overwhelming Rserve (except for the last item)
              if index < total_count - 1
                sleep 5.0  # 5 second delay between submissions
              end
            end
          rescue => e
            logger.error "Failed to submit simulation for datapoint #{dp.uuid}: #{e.message}"
            logger.error e.backtrace.join("\n")
            # Continue with the next datapoint instead of stopping the entire batch
          end
        end
        
        if Rails.application.config.x.job_manager == :resque
          # Delete Redis flag after queuing is done
          logger.info "Deleting Redis queuing flag for #{@analysis_id}"
          Resque.redis.del("analysis:#{@analysis_id}:queuing")
        end        
      else
        logger.info "Using provided data_points options: #{@options[:data_points].size} datapoints"
        ids = @options[:data_points]
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
