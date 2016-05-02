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

  # Perform is the main method that is run in the background.  At the moment if
  # this method crashes it will be logged as a failed delayed_job and will fail
  # after max_attempts.
  def perform
    @analysis = Analysis.find(@analysis_id)

    # get the analysis and report that it is running
    @analysis_job = Analysis::Core.initialize_analysis_job(@analysis, @analysis_job_id, @options)

    # reload the object (which is required) because the subdocuments (jobs) may have changed
    @analysis.reload

    begin
      if @options[:data_points].empty?
        Delayed::Worker.logger.info 'No data points were passed into the options, therefore checking which data points to run'
        @analysis.data_points.where(status: 'na', download_status: 'na').each do |dp|
          Delayed::Worker.logger.info "Adding in #{dp.uuid}"
          dp.status = 'queued'
          dp.save!
          @options[:data_points] << dp.uuid
        end
      end

      # Get the server ip address -- this can fail easily if no ComputeNode exists
      # TODO: Move this to the Cluster Init routine
      server_ip = ComputeNode.where(node_type: 'server').first.ip_address
      logger.info "Server ip: #{server_ip}"
      logger.info 'Starting Batch Run Local'

      # Initialize each worker node
      worker_ips = ComputeNode.worker_ips
      logger.info "Worker node ips #{worker_ips}"

      logger.info 'Running initialize worker scripts'
      run_command = "#{sys_call_ruby} worker_init_final.rb -h #{APP_CONFIG['os_server_host_url']} -a #{@analysis_id} -s initialize"
      logger.info "Running the command: #{run_command}"
      `#{run_command}`
      exit_code = $?.exitstatus
      logger.info "System call of #{run_command} exited with #{exit_code}"
      raise "Could not make system call to run '#{run_command}}'" unless exit_code == 0

      @options[:data_points].each do |dp|
        run_command = "#{sys_call_ruby} simulate_data_point.rb -h #{APP_CONFIG['os_server_host_url']} -a #{@analysis_id} -u #{dp} -x #{@options[:run_data_point_filename]}"
        logger.info "Running the command: #{run_command}"
        `#{run_command}`
        exit_code = $?.exitstatus
        logger.info "System call of #{run_command} exited with #{exit_code}"
        raise "Could not make system call to run '#{run_command}}'" unless exit_code == 0
      end
    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      logger.error log_message
      @analysis.status_message = log_message
      @analysis.save!
    end

    begin
      logger.info 'Running finalize worker scripts'
      run_command = "#{sys_call_ruby} worker_init_final.rb -h #{APP_CONFIG['os_server_host_url']} -a #{@analysis_id} -s finalize"
      `#{run_command}`
      exit_code = $?.exitstatus
      logger.info "System call of #{run_command} exited with #{exit_code}"
      logger.info "Could not make system call to run '#{run_command}}'" unless exit_code == 0
    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      logger.error log_message
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

      logger.info "Finished running analysis '#{self.class.name}'"
    end
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    1
  end

  # Return the logger for the delayed job
  def logger
    Delayed::Worker.logger
  end

  # Return the Ruby system call string for ease
  def sys_call_ruby
    "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/ruby"
    # "cd #{APP_CONFIG['sim_root_path']} && ruby"
  end
end
