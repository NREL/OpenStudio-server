# BatchRunLocal runs simulations in an in memory queue without using R.
# Right now this is attached to an analysis--need to verify if this is
# what we need to do.

class Analysis::BatchRunLocal
  include Analysis::Core

  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = {
      skip_init: false,
      data_points: [],
      run_data_point_filename: 'run_openstudio.rb',
      problem: {}
    }.with_indifferent_access # make sure to set this because the params object from rails is indifferential
    @options = defaults.deep_merge(options)

    @analysis_id = analysis_id
    @analysis_job_id = analysis_job_id
  end

  # Perform is the main method that is run in the background.  At the moment if this method crashes
  # it will be logged as a failed delayed_job and will fail after max_attempts.
  def perform
    @analysis = Analysis.find(@analysis_id)

    # get the analysis and report that it is running
    @analysis_job = Analysis::Core.initialize_analysis_job(@analysis, @analysis_job_id, @options)

    # reload the object (which is required) because the subdocuments (jobs) may have changed
    @analysis.reload

    begin
      if @options[:data_points].empty?
        Rails.logger.info 'No data points were passed into the options, therefore checking which data points to run'
        @analysis.data_points.where(status: 'na', download_status: 'na').each do |dp|
          Rails.logger.info "Adding in #{dp.uuid}"
          dp.status = 'queued'
          dp.save!
          @options[:data_points] << dp.uuid
        end
      end

      # Get the server ip address -- this can fail easily if no ComputeNode exists
      # TODO: Move this to the Cluster Init routine
      server_ip = ComputeNode.where(node_type: 'server').first.ip_address
      Rails.logger.info("Server ip: #{server_ip}")
      Rails.logger.info('Starting Batch Run')

      # Initialize each worker node
      worker_ips = ComputeNode.worker_ips
      Rails.logger.info "Worker node ips #{worker_ips}"

      Rails.logger.info 'Running initialize worker scripts'
      # ruby worker_init_final.rb -h localhost:3000 -a 330f3f4a-dbc0-469f-b888-a15a85ddd5b4 -s initialize
      ruby_command = "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/bundle exec ruby"
      run_command = "#{ruby_command} worker_init_final.rb -h localhost:3000 -a #{@analysis_id} -s initialize"
      Rails.logger.info run_command
      `#{run_command}`

      Rails.logger.info @options[:data_points]
      @options[:data_points].each do |dp|
        # TODO: remove hard coded ip/port
        run_command = "#{ruby_command} simulate_data_point.rb -h localhost:3000 -a #{@analysis_id} -u #{dp} -x #{@options[:run_data_point_filename]}"
        Rails.logger.info run_command
        `#{run_command}`
      end
    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      Rails.logger.error log_message
      @analysis.status_message = log_message
      @analysis.save!
    end

    begin
      Rails.logger.info 'Running finalize worker scripts'
      `cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/bundle exec ruby worker_init_final.rb -h localhost:3000 -a #{@analysis_id} -s finalize`
    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      Rails.logger.error log_message
      @analysis.status_message += log_message
      @analysis.save!
    ensure
      # Only set this data if the analysis was NOT called from another analysis
      unless @options[:skip_init]
        @analysis_job.end_time = Time.now
        @analysis_job.status = 'completed'
        @analysis_job.save!
        @analysis.reload
      end
      @analysis.save!

      Rails.logger.info "Finished running analysis '#{self.class.name}'"
    end
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    1
  end
end
