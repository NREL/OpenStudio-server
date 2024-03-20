# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Command line based interface to execute the Workflow manager.

module DjJobs
  class RunSimulateDataPoint
    include DjJobs::UrbanOpt
    require 'date'
    require 'json'

    def initialize(data_point_id, options = {})
      @data_point = DataPoint.find(data_point_id)
      @options = options
      @intialize_worker_errs = []

      # this is also run from resque job, which leverages perform code below.
      # only queue data_point on initialize for delayed_jobs
      @data_point.set_queued_state if Rails.application.config.job_manager == :delayed_job

      # Create the analysis, simulation, and run directory
      FileUtils.mkdir_p analysis_dir unless Dir.exist? analysis_dir
      FileUtils.mkdir_p simulation_dir unless Dir.exist? simulation_dir
      FileUtils.rm_rf run_dir if Dir.exist? run_dir
      FileUtils.mkdir_p run_dir unless Dir.exist? run_dir

      # Logger for the simulate datapoint
      @sim_logger = Logger.new("#{simulation_dir}/#{@data_point.id}.log")
    end

    def perform
      # Error if @datapoint doesn't exist
      if @data_point.nil?
        @sim_logger = 'Could not find datapoint; @datapoint was nil'
        return
      end

      @data_point.set_start_state

      # Register meta-level info
      @sim_logger.info "Server host is #{APP_CONFIG['os_server_host_url']}"
      @sim_logger.info "Analysis directory is #{analysis_dir}"
      @sim_logger.info "Simulation directory is #{simulation_dir}"
      @sim_logger.info "Run datapoint type/file is #{@options[:run_workflow_method]}"

      # If worker initialization fails, communicate this information
      # to the user via the out.osw.
      success = initialize_worker
      unless success
        err_msg_1 = 'The worker initialization failed, which means that no simulations will be run.'
        err_msg_2 = 'If you see this message once, all subsequent runs will likely fail.'
        err_msg_3 = 'If you are running PAT simulations locally on Windows, the error is likely due to a measure file whose path length has exceeded 256 characters.'
        err_msg_4 = 'Inspect the following messages for clues as to the specific issue:'
        out_osw = { completed_status: 'Fail',
                    osa_id: @data_point.analysis.id,
                    osd_id: @data_point.id,
                    name: @data_point.name,
                    completed_at: ::DateTime.now.iso8601,
                    started_at: ::DateTime.now.iso8601,
                    steps: [
                      arguments: {},
                      description: '',
                      name: 'Initialize Worker Error',
                      result: {
                        completed_at: ::DateTime.now.iso8601,
                        started_at: ::DateTime.now.iso8601,
                        stderr: "Please see the delayed_jobs.log and / or #{@data_point.id}.log file for the specific error.",
                        stdout: '',
                        step_errors: [err_msg_1, err_msg_2, err_msg_3, err_msg_4] + @intialize_worker_errs,
                        step_files: [],
                        step_info: [],
                        step_result: 'Failure',
                        step_warnings: []
                      }
                    ] }
        report_file = "#{simulation_dir}/out.osw"
        File.open(report_file, 'wb') do |f|
          f.puts ::JSON.pretty_generate(out_osw)
        end
        upload_file(report_file, 'Report', nil, 'application/json') if File.exist?(report_file)
        @data_point.set_error_flag
        @data_point&.set_complete_state
        @sim_logger.error "Failed to initialize the worker. #{err_msg_3}"
        @sim_logger&.close
        report_file = "#{simulation_dir}/#{@data_point.id}.log"
        upload_file(report_file, 'Report', 'Datapoint Simulation Log', 'application/text') if File.exist?(report_file)
        return false
      end

      # delete any existing data files from the server in case this is a 'rerun'
      @sim_logger.info 'RestClient delete'
      post_count = 0
      post_count_max = 50
      begin
        post_count += 1
        @sim_logger.info "delete post_count = #{post_count}"
        RestClient.delete "#{APP_CONFIG['os_server_host_url']}/data_points/#{@data_point.id}/result_files"
      rescue StandardError => e
        sleep Random.new.rand(1.0..10.0)
        retry if post_count <= post_count_max
        @sim_logger.error "RestClient.delete failed with error #{e.message}"
        raise "RestClient.delete failed with error #{e.message}"
      end
      # Download the datapoint to run and save to disk
      url = "#{APP_CONFIG['os_server_host_url']}/data_points/#{@data_point.id}.json"
      @sim_logger.info "Downloading datapoint from #{url}"
      post_count = 0
      post_count_max = 50
      begin
        post_count += 1
        @sim_logger.info "get url post_count = #{post_count}"
        r = RestClient.get url
      rescue StandardError => e
        sleep Random.new.rand(1.0..10.0)
        retry if post_count <= post_count_max
        @sim_logger.error "RestClient.get url failed with error #{e.message}"
        raise "RestClient.get url failed with error #{e.message}"
      end
      raise 'Datapoint JSON could not be downloaded' unless r.code == 200
      # Parse to JSON to save it again with nice formatting
      File.open("#{simulation_dir}/data_point.json", 'w') { |f| f << JSON.pretty_generate(JSON.parse(r)) }

      # copy over required file to the run directory
      FileUtils.cp "#{analysis_dir}/analysis.json", "#{simulation_dir}/analysis.json"
      osw_path = "#{simulation_dir}/data_point.osw"
      # PAT puts seeds in "seeds" folder (not "seed")
      osw_options = {
        file_paths: ['../weather', '../seeds', '../seed'],
        measure_paths: ['../measures']
      }
      if @data_point.seed
        osw_options[:seed] = @data_point.seed unless @data_point.seed == ''
      end
      if @data_point.da_descriptions
        osw_options[:da_descriptions] = @data_point.da_descriptions unless @data_point.da_descriptions == []
      end
      if @data_point.weather_file
        osw_options[:weather_file] = @data_point.weather_file unless @data_point.weather_file == ''
      end
      @sim_logger.info 'Calling OpenStudio-Analysis-Gem new instance'
      t = OpenStudio::Analysis::Translator::Workflow.new(
        "#{simulation_dir}/analysis.json",
        osw_options
      )
      @sim_logger.info 'Calling OpenStudio-Analysis-Gem process_datapoint'
      t_result = t.process_datapoint("#{simulation_dir}/data_point.json")
      if t_result
        if @data_point.analysis.urbanopt
          t_result[:urbanopt] = true
        end
        File.open(osw_path, 'w') { |f| f << JSON.pretty_generate(t_result) }
      else
        raise 'Could not translate OSA, OSD into OSW'
      end
      @sim_logger.info 'Creating Workflow Manager instance'
      @sim_logger.info "Directory is #{simulation_dir}"
      run_log_file = File.join(run_dir, 'run.log')
      @sim_logger.info "Opening run.log file '#{run_log_file}'"
      # add check for valid CLI option or ""
      unless ['', '--debug'].include?(@data_point.analysis.cli_debug)
        @sim_logger.warn "CLI_Debug option: #{@data_point.analysis.cli_debug} is not valid.  Using --debug instead."
        @data_point.analysis.cli_debug = '--debug'
      end
      unless ['', '--verbose'].include?(@data_point.analysis.cli_verbose)
        @sim_logger.warn "CLI_Verbose option: #{@data_point.analysis.cli_verbose} is not valid.  Using --verbose instead."
        @data_point.analysis.cli_verbose = '--verbose'
      end
      # Fail gracefully if the datapoint errors out by returning the zip and out.osw
      begin
        # Make sure to pass in preserve_run_dir
        run_result = nil
        File.open(run_log_file, 'a') do |run_log|
          begin
            if @data_point.analysis.urbanopt
              uo_simulation_log = File.join(simulation_dir, 'urbanopt_simulation.log')
              uo_process_log = File.join(simulation_dir, 'urbanopt_process.log')
              run_urbanopt(uo_simulation_log, uo_process_log)
            else  #OS CLI workflow
              @sim_logger.info "analysis is configured with #{@data_point.analysis.to_json}"
              if @data_point.analysis.gemfile
                cmd = "#{Utility::Oss.oscli_cmd_bundle_args(@sim_logger, analysis_dir)} classic #{@data_point.analysis.cli_verbose} run --workflow #{osw_path} #{@data_point.analysis.cli_debug}"
              else
                cmd = "#{Utility::Oss.oscli_cmd_no_bundle_args(@sim_logger)} classic #{@data_point.analysis.cli_verbose} run --workflow #{osw_path} #{@data_point.analysis.cli_debug}"
              end
              process_log = File.join(simulation_dir, 'oscli_simulation.log')
              @sim_logger.info "Running workflow using cmd #{cmd} and writing log to #{process_log}"
              oscli_env_unset = Hash[Utility::Oss::ENV_VARS_TO_UNSET_FOR_OSCLI.collect{|x| [x,nil]}]
              pid = Process.spawn(oscli_env_unset, cmd, [:err, :out] => [process_log, 'w'])
              # add check for a valid timeout value
              unless @data_point.analysis.run_workflow_timeout.positive?
                @sim_logger.warn "run_workflow_timeout option: #{@data_point.analysis.run_workflow_timeout} is not valid.  Using 28800s instead."
                @@data_point.analysis.run_workflow_timeout = 28800
              end
              Timeout.timeout(@data_point.analysis.run_workflow_timeout) do
                Process.wait(pid)
              end

              if $?.exitstatus != 0
                raise "Oscli returned error code #{$?.exitstatus}"
              end
            end  
          rescue Timeout::Error
            @sim_logger.error "Killing process for #{osw_path} due to timeout."
            # openstudio process actually runs in a child of pid.  to prevent orphaned processes on timeout, we
            # need to identify the child and kill it as well.
            # exception handing and a lot of logging in case we discover cases with >1 child process or other behavior
            # that is not currently handled.
            begin
              @sim_logger.info "looking up any children of timed out process #{pid}"
              child_pid = `ps -o pid= --ppid "#{pid}"`.to_i
              if child_pid > 0
                @sim_logger.info "killing child #{child_pid} of timed out process #{pid}"
                Process.kill('KILL', child_pid)
              end
              @sim_logger.info "killing timed out process #{pid}"
              Process.kill('KILL', pid)
            rescue Exception => e
              @sim_logger.error "Error killing process #{pid}: #{e}"
            end

            run_result = :errored
          rescue ScriptError => e # This allows us to handle LoadErrors and SyntaxErrors in measures
            log_message = "The workflow failed with script error #{e.message} in #{e.backtrace.join("\n")}"
            @sim_logger&.error log_message
            run_result = :errored
          rescue Exception => e
            @sim_logger.error "Workflow #{osw_path} failed with error #{e}"
            run_result = :errored
          ensure
            if (!uo_simulation_log.nil? && File.exist?(uo_simulation_log))
              @sim_logger.info "UrbanOpt simulation output: #{File.read(uo_simulation_log)}"
            else
              @sim_logger.warn "UrbanOpt simulation output: #{uo_simulation_log} does not exist"            
            end
            if (!uo_process_log.nil? && File.exist?(uo_process_log))
              @sim_logger.info "UrbanOpt process output: #{File.read(uo_process_log)}"
            else
              @sim_logger.warn "UrbanOpt process output: #{uo_process_log} does not exist"
            end
            if (!process_log.nil? && File.exist?(process_log))
              @sim_logger.info "Oscli output: #{File.read(process_log)}"
            else
              @sim_logger.warn "OSCLI output: #{process_log} does not exist"
            end
            #docker_log = File.join(APP_CONFIG['rails_log_path'], 'docker.log')
            #if File.exist? docker_log
            #   @sim_logger.info "docker.log output: #{File.read(docker_log)}"
            #end
            #resque_log = File.join(APP_CONFIG['rails_log_path'], 'resque.log')
            #if File.exist? resque_log
            #   @sim_logger.info "resque.log output: #{File.read(resque_log)}"
            #end
          end
        end
        if run_result == :errored
          @data_point.set_error_flag
          @data_point.sdp_log_file = File.read(run_log_file).lines if File.exist? run_log_file

          report_file = "#{simulation_dir}/out.osw"
          @sim_logger.info "Uploading #{report_file} which exists? #{File.exist?(report_file)}"
          upload_file(report_file, 'Report', nil, 'application/json') if File.exist?(report_file)

          report_file = "#{run_dir}/data_point.zip"
          @sim_logger.info "Uploading #{report_file} which exists? #{File.exist?(report_file)}"
          upload_file(report_file, 'Data Point', 'Zip File') if File.exist?(report_file)
        else
          # Save the log to the data point. This does not update while running, rather
          # it is saved at the very end of the simulation.
          if File.exist? run_log_file
            @data_point.sdp_log_file = File.read(run_log_file).lines
          end

          # Save the results to the database - I was PUTing these to the server,
          # but the values were not be typed correctly within RestClient. Since
          # this is running as a delayed job, then access to mongoid methods is okay.
          results_file = "#{run_dir}/measure_attributes.json"
          if File.exist? results_file
            results = JSON.parse(File.read(results_file), symbolize_names: true)
            @data_point.update(results: results)
          else
            #run_result = :errored  #This should not be an error for workflows with no measures
            @sim_logger.warn "Could not find results #{results_file}"
          end

          @sim_logger.info 'Saving files/reports back to the server'

          # Post the reports back to the server
          uploads_successful = []
          if @data_point.analysis.download_reports
            @sim_logger.info 'downloading reports/*.{html,json,csv,xml,mat}'
            Dir["#{simulation_dir}/reports/*.{html,json,csv,xml,mat}"].each { |rep| uploads_successful << upload_file(rep, 'Report') }
          else
            @sim_logger.info "NOT downloading /reports/*.{html,json,csv,xml,mat} since download_reports value is: #{@data_point.analysis.download_reports}"
          end
          report_file = "#{run_dir}/objectives.json"
          uploads_successful << upload_file(report_file, 'Report', 'objectives', 'application/json') if File.exist?(report_file)
          if @data_point.analysis.download_osw
            @sim_logger.info 'downloading out.OSW'
            report_file = "#{simulation_dir}/out.osw"
            uploads_successful << upload_file(report_file, 'Report', 'Final OSW File', 'application/json') if File.exist?(report_file)
          else
            @sim_logger.info "NOT downloading out.OSW since download_osw value is: #{@data_point.analysis.download_osw}"
          end
          if @data_point.analysis.download_osm
            @sim_logger.info 'downloading in.OSM'
            report_file = "#{run_dir}/in.osm"
            uploads_successful << upload_file(report_file, 'OpenStudio Model', 'model', 'application/osm') if File.exist?(report_file)
          else
            @sim_logger.info "NOT downloading in.OSM since download_osm value is: #{@data_point.analysis.download_osm}"
          end
          if @data_point.analysis.download_zip
            @sim_logger.info 'downloading datapoint.ZIP'
            report_file = "#{run_dir}/data_point.zip"
            uploads_successful << upload_file(report_file, 'Data Point', 'Zip File', 'application/zip') if File.exist?(report_file)
          else
            @sim_logger.info "NOT downloading datapoint.zip since download_zip value is: #{@data_point.analysis.download_zip}"
          end
          @sim_logger.info "run_result: #{run_result}"
          run_result = :errored unless uploads_successful.all?
          @sim_logger.info "uploads_successful.all?: #{uploads_successful.all?}"
          @sim_logger.info "run_result: #{run_result}"
        end

        # Run any data point finalization scripts - note this currently runs whether or not the datapoint errored out
        run_script_with_args 'finalize'

        report_file = "#{run_dir}/datapoint_final.log"
        uploads_successful << upload_file(report_file, 'Report', 'Finalization Script Log', 'application/txt') if File.exist?(report_file)

        # Set completed state and return
        if run_result != :errored
          if File.exist? "#{simulation_dir}/out.osw"
            status = JSON.parse(File.read("#{simulation_dir}/out.osw"), symbolize_names: true)[:completed_status]
            @sim_logger.info "status: #{status}"
          else
            raise "Could not find out.osw file at #{simulation_dir}/out.osw"
          end
          if status == 'Invalid'
            @data_point.set_invalid_flag
          elsif status == 'Cancel'
            @data_point.set_cancel_flag
          elsif status == 'Success'
            @data_point.set_success_flag
          else
            raise "Unknown completion status of #{status} in out.osw file."
          end
        else
          @data_point.set_error_flag
        end
      rescue ScriptError, NoMemoryError, StandardError => e
        log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
        @sim_logger&.error log_message
        @data_point.set_error_flag
        @data_point.sdp_log_file = File.read(run_log_file).lines if File.exist? run_log_file
      ensure
        @sim_logger.info "cleaning up /tmp directory"
        #remove xmlvalidation directories left in /tmp from OS
        pattern = '/tmp/xmlvalidation*'
        # Find and remove directories matching the pattern
        Dir.glob(pattern).each do |dir|
          if File.directory?(dir)
            FileUtils.rm_rf(dir)
          end
        end
        @sim_logger&.info "Finished #{__FILE__}"
        @data_point&.set_complete_state
        @sim_logger&.close
        report_file = "#{simulation_dir}/#{@data_point.id}.log"
        upload_file(report_file, 'Report', 'Datapoint Simulation Log', 'application/text') if File.exist?(report_file)
        #delete the simulation directory (default is true)
        FileUtils.rm_rf simulation_dir if @data_point.analysis.delete_simulation_dir
        true
      end
    end

    # Method to download and unzip the analysis data. This has some logic
    # in order to handle multiple instances trying to download the file at the
    # same time.
    def initialize_worker
      @sim_logger.info "Starting initialize_worker for datapoint #{@data_point.id}"

      write_lock_file = "#{analysis_dir}/analysis_zip.lock"
      receipt_file = "#{analysis_dir}/analysis_zip.receipt"

      # Check if the receipt file exists, if so, then just return out of this method immediately
      if File.exist? receipt_file
        @sim_logger.info 'receipt_file already exists, moving on'
        return true
      end
      # add check for a valid timeout value
      unless @data_point.analysis.initialize_worker_timeout.positive?
        @sim_logger.warn "initialize_worker_timeout option: #{@data_point.analysis.initialize_worker_timeout} is not valid.  Using 28800s instead."
        @@data_point.analysis.initialize_worker_timeout = 28800
      end
      # This block makes this code threadsafe for non-docker deployments, i.e. desktop usage
      if File.exist? write_lock_file
        @sim_logger.info 'write_lock_file exists, checking & waiting for receipt file'

        # wait until receipt file appears then return or error
        begin
          Timeout.timeout(@data_point.analysis.initialize_worker_timeout) do
            loop do
              break if File.exist? receipt_file

              @sim_logger.info 'waiting for receipt file to appear'
              sleep 3
            end
          end

          @sim_logger.info 'receipt_file appeared, moving on'
          return true
        rescue ::Timeout::Error
          @sim_logger.error "Required analysis objects were not retrieved after #{@data_point.analysis.initialize_worker_timeout} seconds."
        end
      else
        # Try to download the analysis zip, but first lock simultanious threads
        write_lock(write_lock_file) do |_|
          zip_download_count = 0
          zip_max_download_count = 12
          download_file = "#{analysis_dir}/analysis.zip"
          download_url = "#{APP_CONFIG['os_server_host_url']}/analyses/#{@data_point.analysis.id}/download_analysis_zip"
          @sim_logger.info "Downloading analysis zip from #{download_url}"
          sleep Random.new.rand(5.0) # Try and stagger the initial hits to the zip download url
          begin
            Timeout.timeout(@data_point.analysis.initialize_worker_timeout) do
              zip_download_count += 1
              File.open(download_file, 'wb') do |saved_file|
                # the following "open" is provided by open-uri
                open(download_url, 'rb') do |read_file|
                  saved_file.write(read_file.read)
                end
              end
            end
          rescue StandardError => e
            FileUtils.rm_f download_file if File.exist? download_file
            sleep Random.new.rand(1.0..10.0)
            retry if zip_download_count < zip_max_download_count
            raise "Could not download the analysis zip after #{zip_max_download_count} attempts. Failed with message #{e.message}."
          end

          # Extract the zip
          extract_count = 0
          extract_max_count = 3
          @sim_logger.info "Extracting analysis zip to #{analysis_dir}"
          begin
            Timeout.timeout(@data_point.analysis.initialize_worker_timeout) do
              extract_count += 1
	      # The method call below is failing on windows due to ruby bindings issue. see https://github.com/NREL/OpenStudio/issues/3942
	      # This is local function for workaround until that is resolved
              #OpenStudio::Workflow.extract_archive(download_file, analysis_dir)
              extract_archive(download_file, analysis_dir)
            end
          rescue StandardError => e
            retry if extract_count < extract_max_count
            raise "Extraction of the analysis.zip file failed #{extract_max_count} times with error #{e.message}"
          end

          # Download only one copy of the analysis.json
          json_download_count = 0
          json_max_download_count = 12
          analysis_json_file = "#{analysis_dir}/analysis.json"
          analysis_json_url = "#{APP_CONFIG['os_server_host_url']}/analyses/#{@data_point.analysis.id}.json"
          @sim_logger.info "Downloading analysis.json from #{analysis_json_url}"
          begin
            Timeout.timeout(@data_point.analysis.initialize_worker_timeout) do
              json_download_count += 1
              a = RestClient.get analysis_json_url
              raise "Analysis JSON could not be downloaded - responce code of #{a.code} received." unless a.code == 200

              # Parse to JSON to save it again with nice formatting
              File.open(analysis_json_file, 'w') { |f| f << JSON.pretty_generate(JSON.parse(a)) }
            end
          rescue StandardError => e
            FileUtils.rm_f analysis_json_file if File.exist? analysis_json_file
            sleep Random.new.rand(1.0..10.0)
            retry if json_download_count < json_max_download_count
            raise "Downloading and extracting the analysis JSON failed #{json_max_download_count} with message #{e.message}"
          end

          #moved back to datapoint
          ## Check for UO and bundle
          #if @data_point.analysis.urbanopt
          #  #bundle install
          #  bundle_count = 0
          #  bundle_max_count = 10
          #  begin
          #    cmd = "cd #{analysis_dir}/lib/urbanopt; bundle install --path=#{analysis_dir}/lib/urbanopt/ --gemfile=#{analysis_dir}/lib/urbanopt/Gemfile --retry 10"
          #    uo_bundle_log = File.join(analysis_dir, 'urbanopt_bundle.log')
          #    @sim_logger.info "Installing UrbanOpt bundle using cmd #{cmd} and writing log to #{uo_bundle_log}"
          #    pid = Process.spawn(cmd, [:err, :out] => [uo_bundle_log, 'w'])
          #    Timeout.timeout(@data_point.analysis.initialize_worker_timeout) do
          #      bundle_count += 1
          #      Process.wait(pid)
          #    end
          #  rescue StandardError => e
          #    sleep Random.new.rand(1.0..10.0)
          #    retry if bundle_count < bundle_max_count
          #    raise "Could not bundle UrbanOpt after #{bundle_max_count} attempts. Failed with message #{e.message}."
          #  ensure
          #    uo_log("urbanopt_bundle") if @data_point.analysis.urbanopt
          #  end
          #end
          # Now tell all other future data-points that it is okay to skip this step by creating the receipt file.
          File.open(receipt_file, 'w') { |f| f << Time.now }
        end

        # Run the server data_point initialization script with defined arguments, if it exists.
        run_script_with_args 'initialize'
        run_bundle_gems if @data_point.analysis.gemfile
      
      end

      @sim_logger.info 'Finished worker initialization'
      return true
    rescue StandardError => e
      @sim_logger.error "Error in initialize_worker in #{__FILE__} with message #{e.message}; #{e.backtrace.join("\n")}"
      @intialize_worker_errs << "#{e.message}; #{e.backtrace.first}"
      return false
    end

    # Simple method to write a lock file in order for competing threads to wait before continuing.
    def write_lock(lock_file_path)
      lock_file = File.open(lock_file_path, 'a')
      begin
        lock_file.flock(File::LOCK_EX)
        lock_file << Time.now

        yield
      ensure
        lock_file.flock(File::LOCK_UN)
      end
    end

    #add UrbanOpt log to sim log
    def uo_log(file_name)
      uo_log = File.join(simulation_dir, "#{file_name}.log")
      if File.exist? uo_log
        @sim_logger.info "UrbanOpt #{file_name}.log output: #{File.read(uo_log)}"
      else  
        @sim_logger.error "UrbanOpt #{simulation_dir}/#{file_name}.log does not exist}"
      end
    end
    private

    def data_point_url
      "#{APP_CONFIG['os_server_host_url']}/data_points/#{@data_point.id}/upload_file"
    end

    def analysis_dir
      "#{APP_CONFIG['sim_root_path']}/analysis_#{@data_point.analysis.id}"
    end

    def simulation_dir
      "#{analysis_dir}/data_point_#{@data_point.id}"
    end

    def run_dir
      "#{simulation_dir}/run"
    end

    # Return the logger for delayed jobs which is typically rails_root/log/delayed_job.log
    def logger
      if Rails.application.config.job_manager == :delayed_job
        Delayed::Worker.logger
      elsif Rails.application.config.job_manager == :resque
        Resque.logger
      else
        raise 'Rails.application.config.job_manager must be set to :resque or :delayed_job'
      end
    end

    # The method call below is failing on windows due to ruby bindings issue. see https://github.com/NREL/OpenStudio/issues/3942
    # This is local function for workaround until that is resolved
    #OpenStudio::Workflow.extract_archive(download_file, analysis_dir)
    def extract_archive(archive_filename, destination, overwrite = true)
      ::Zip.sort_entries = true
      Zip::File.open(archive_filename) do |zf|
        zf.each do |f|
          @sim_logger.info "Zip: Extracting #{f.name}"
          f_path = File.join(destination, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          if File.exist?(f_path)
            @sim_logger.warn "SKIPPED: #{f.name}, already existed."
          else
            zf.extract(f, f_path)
          end
        end
      end
    end

    def upload_file(filename, type, display_name = nil, content_type = nil)
      upload_file_attempt = 0
      upload_file_max_attempt = 4
      display_name ||= File.basename(filename, '.*')
      @sim_logger.info "Saving report #{filename} to #{data_point_url}"
      # add check for a valid timeout value
      unless @data_point.analysis.upload_results_timeout.positive?
        @sim_logger.warn "upload_results_timeout option: #{@data_point.analysis.upload_results_timeout} is not valid.  Using 28800s instead."
        @@data_point.analysis.upload_results_timeout = 28800
      end
      begin
        Timeout.timeout(@data_point.analysis.upload_results_timeout) do
          upload_file_attempt += 1
          if content_type
            res = RestClient.post(data_point_url,
                                  file: { display_name: display_name,
                                          type: type,
                                          attachment: File.new(filename, 'rb') },
                                  content_type: content_type)
          else
            res = RestClient.post(data_point_url,
                                  file: { display_name: display_name,
                                          type: type,
                                          attachment: File.new(filename, 'rb') })
          end
          @sim_logger.info "Saving report responded with #{res}"
          return true
        end
      rescue StandardError => e
        sleep Random.new.rand(1.0..10.0)
        retry if upload_file_attempt < upload_file_max_attempt
        @sim_logger.error "Could not save report #{display_name} with message: #{e.message} in #{e.backtrace.join("\n")}"
        return false
      end
    end

    def run_script_with_args(script_name)
      dir_path = "#{analysis_dir}/scripts/data_point"
      #  paths to check for args and script files
      args_path = "#{dir_path}/#{script_name}.args"
      script_path = "#{dir_path}/#{script_name}.sh"
      log_path = "#{analysis_dir}/data_point_#{@data_point.id}/#{script_name}.log"

      @sim_logger.info "Checking for presence of args file at #{args_path}"
      args = nil
      if File.file? args_path
        args = Utility::Oss.load_args args_path
        @sim_logger.info " args loaded from file #{args_path}: #{args}"
      end

      @sim_logger.info "Checking for presence of script file at #{script_path}"
      if File.file? script_path
        Utility::Oss.run_script(script_path, 4.hours, { 'SCRIPT_ANALYSIS_ID' => @data_point.analysis.id, 'SCRIPT_DATA_POINT_ID' => @data_point.id }, args, @sim_logger, log_path)
      end
    rescue StandardError => e
      msg = "Error #{e.message} running #{script_name}: #{e.backtrace.join("\n")}"
      @sim_logger.error msg
      raise msg
    ensure
      # save the log information to the datapoint if it exists
      if File.exist? log_path
        @data_point.worker_logs[script_name] = File.read(log_path).lines
      end
    end

    def run_bundle_gems
      @sim_logger.info "Installing gems" 
      if File.file? "#{analysis_dir}/Gemfile"
        @sim_logger.info "Gemfile found in: #{analysis_dir}"
      else
        @sim_logger.info "Gemfile not found at #{analysis_dir}" 
        return false
      end

      log_path = "#{analysis_dir}/bundle.log"
      cmd = "bundle install --gemfile=#{analysis_dir}/Gemfile --path=#{analysis_dir}/gems"
      oscli_env_unset = Hash[Utility::Oss::ENV_VARS_TO_UNSET_FOR_OSCLI.collect{|x| [x,nil]}]
      @sim_logger.info "Bundle install command: #{cmd}"
      pid = Process.spawn(oscli_env_unset, cmd, [:err, :out] => [log_path, 'w'])
      Process.wait pid
      @sim_logger.info "gem installation complete" 
      @sim_logger.info File.read(log_path).lines

    rescue StandardError => e
      msg = "Error #{e.message} running #{cmd}: #{e.backtrace.join("\n")}"
      @sim_logger.error msg
      raise msg
    end
  end
end
