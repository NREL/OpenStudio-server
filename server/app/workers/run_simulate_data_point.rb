# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
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

# Command line based interface to execute the Workflow manager.

class RunSimulateDataPoint

  require 'date'
  require 'json'

  def initialize(data_point_id, options = {})
    # as there have been issues requiring full path on linux/osx, use which openstudio to pull absolute path
    os_cmd = (Gem.win_platform? || ENV['OS'] == 'Windows_NT') ? 'openstudio.exe' : `which openstudio`.strip
    defaults = ActiveSupport::HashWithIndifferentAccess.new(openstudio_executable: os_cmd )
    @options = defaults.deep_merge(options)

    @data_point = DataPoint.find(data_point_id)
    @data_point.status = :queued
    @data_point.run_queue_time = Time.now
    @intialize_worker_errs = []
  end

  def perform
    # Create the analysis, simulation, and run directory
    FileUtils.mkdir_p analysis_dir unless Dir.exist? analysis_dir
    FileUtils.mkdir_p simulation_dir unless Dir.exist? simulation_dir
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir unless Dir.exist? run_dir

    # Logger for the simulate datapoint
    @sim_logger = Logger.new("#{simulation_dir}/#{@data_point.id}.log")

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

    # If worker initialization fails, communicate this information
    # to the user via the out.osw.
    success = initialize_worker
    unless success
      err_msg_1 = 'The worker initialization failed, which means that no simulations will be run.'
      err_msg_2 = 'If you see this message once, all subsequent runs will likely fail.'
      err_msg_3 = 'If you are running PAT simulations locally on Windows, the error is likely due to a measure file whose path length has exceeded 256 characters.'
      err_msg_4 = 'Inspect the following messages for clues as to the specific issue:'
      out_osw = {completed_status: 'Fail',
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
                 ]}
      report_file = "#{simulation_dir}/out.osw"
      File.open(report_file, 'wb') do |f|
        f.puts ::JSON.pretty_generate(out_osw)
      end
      upload_file(report_file, 'Report', nil, 'application/json') if File.exist?(report_file)
      @data_point.set_error_flag
      @data_point.set_complete_state if @data_point
      @sim_logger.error "Failed to initialize the worker. #{err_msg_3}"
      @sim_logger.close if @sim_logger
      report_file = "#{simulation_dir}/#{@data_point.id}.log"
      upload_file(report_file, 'Report', 'Datapoint Simulation Log', 'application/text') if File.exist?(report_file)
      return false
    end

    # delete any existing data files from the server in case this is a 'rerun'
    RestClient.delete "#{APP_CONFIG['os_server_host_url']}/data_points/#{@data_point.id}/result_files"

    # Download the datapoint to run and save to disk
    url = "#{APP_CONFIG['os_server_host_url']}/data_points/#{@data_point.id}.json"
    @sim_logger.info "Downloading datapoint from #{url}"
    r = RestClient.get url
    raise 'Datapoint JSON could not be downloaded' unless r.code == 200
    # Parse to JSON to save it again with nice formatting
    File.open("#{simulation_dir}/data_point.json", 'w') { |f| f << JSON.pretty_generate(JSON.parse(r)) }

    # copy over required file to the run directory
    FileUtils.cp "#{analysis_dir}/analysis.json", "#{simulation_dir}/analysis.json"

    osw_path = "#{simulation_dir}/data_point.osw"
    # PAT puts seeds in "seeds" folder (not "seed")
    osw_options = {
        file_paths: %w(../weather ../seeds ../seed),
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
    t = OpenStudio::Analysis::Translator::Workflow.new(
        "#{simulation_dir}/analysis.json",
        osw_options
    )
    t_result = t.process_datapoint("#{simulation_dir}/data_point.json")
    if t_result
      File.open(osw_path, 'w') { |f| f << JSON.pretty_generate(t_result) }
    else
      raise 'Could not translate OSA, OSD into OSW'
    end

    @sim_logger.info 'Creating Workflow Manager instance'
    @sim_logger.info "Directory is #{simulation_dir}"
    run_log_file = File.join(run_dir, 'run.log')
    @sim_logger.info "Opening run.log file '#{run_log_file}'"

    # Fail gracefully if the datapoint errors out by returning the zip and out.osw
    begin
      # Make sure to pass in preserve_run_dir
      run_result = nil
      File.open(run_log_file, 'a') do |run_log|
        begin
          # use bundle option only if we have a path to openstudio gemfile.  expect this to be
          bundle = Rails.application.config.os_gemfile_path.present? ? "--bundle "\
            "#{File.join Rails.application.config.os_gemfile_path, 'Gemfile'} --bundle_path "\
            "#{File.join Rails.application.config.os_gemfile_path, 'custom_gems'} --verbose " : ""
          cmd = "#{@options[:openstudio_executable]} #{bundle}run --workflow #{osw_path} --debug"
          @sim_logger.info "Running workflow using cmd #{cmd}"

          # TODO confirm that any ENV variables that we want OSS to use are set correctly, probably pass explicitly to spawn
          pid = Process.spawn(cmd)
          # give it 4 hours
          Timeout.timeout(60*60*4) do
            Process.wait(pid)
          end
        rescue Timeout::Error
          @sim_logger.error "Killing process for #{osw_path} due to timeout."
          Process.kill('TERM', pid)
          run_result = :errored
        rescue ScriptError => e # This allows us to handle LoadErrors and SyntaxErrors in measures
          log_message = "The workflow failed with script error #{e.message} in #{e.backtrace.join("\n")}"
          @sim_logger.error log_message if @sim_logger
          run_result = :errored
        rescue Exception => e
          @sim_logger.error "Workflow #{osw_path} failed with error #{e}"
          run_result = :errored
        end
      end
      failed_run_file = "#{run_dir}/failed.job"
      # with cli, check for presence of run/failed.job
      if File.exist?(failed_run_file)
        @data_point.set_error_flag
        @data_point.sdp_log_file = File.read(run_log_file).lines if File.exist? run_log_file

        report_file = "#{simulation_dir}/out.osw"
        puts "Uploading #{report_file} which exists? #{File.exist?(report_file)}"
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
          raise "Could not find results #{results_file}"
        end

        @sim_logger.info 'Saving files/reports back to the server'

        # Post the reports back to the server
        uploads_successful = []

        Dir["#{simulation_dir}/reports/*.{html,json,csv}"].each { |rep| uploads_successful << upload_file(rep, 'Report') }

        report_file = "#{run_dir}/objectives.json"
        uploads_successful << upload_file(report_file, 'Report', 'objectives', 'application/json') if File.exist?(report_file)

        report_file = "#{simulation_dir}/out.osw"
        uploads_successful << upload_file(report_file, 'Report', 'Final OSW File', 'application/json') if File.exist?(report_file)

        report_file = "#{simulation_dir}/in.osm"
        uploads_successful << upload_file(report_file, 'OpenStudio Model', 'model', 'application/osm') if File.exist?(report_file)

        report_file = "#{run_dir}/data_point.zip"
        uploads_successful << upload_file(report_file, 'Data Point', 'Zip File', 'application/zip') if File.exist?(report_file)

        run_result = :errored unless uploads_successful.all?
      end

      # Run any data point finalization scripts
      begin
        Timeout.timeout(600) do
          files = Dir.glob("#{analysis_dir}/scripts/worker_finalization/*").select { |f| !f.match(/.*args$/) }.map { |f| File.basename(f) }
          files.each do |f|
            @sim_logger.info "Found data point finalization file #{f}."
            run_file(analysis_dir, 'finalization', f)
          end
        end
      rescue => e
        @sim_logger.error "Error in data point finalization script: #{e.message} in #{e.backtrace.join("\n")}"
        run_result = :errored
      end

      report_file = "#{run_dir}/datapoint_final.log"
      uploads_successful << upload_file(report_file, 'Report', 'Finalization Script Log', 'application/txt') if File.exist?(report_file)

      # Set completed state and return
      if run_result != :errored
        if File.exist? "#{simulation_dir}/out.osw"
          status = JSON.parse(File.read("#{simulation_dir}/out.osw"), symbolize_names: true)[:completed_status]
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
      @sim_logger.error log_message if @sim_logger
      @data_point.set_error_flag
      @data_point.sdp_log_file = File.read(run_log_file).lines if File.exist? run_log_file
    ensure
      @sim_logger.info "Finished #{__FILE__}" if @sim_logger
      @sim_logger.close if @sim_logger
      @data_point.set_complete_state if @data_point
      report_file = "#{simulation_dir}/#{@data_point.id}.log"
      upload_file(report_file, 'Report', 'Datapoint Simulation Log', 'application/text') if File.exist?(report_file)
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

    # This block makes this code threadsafe for non-docker deployments, i.e. desktop usage
    if File.exist? write_lock_file
      @sim_logger.info 'write_lock_file exists, checking & waiting for receipt file'

      # wait until receipt file appears then return or error
      zip_download_timeout = 240
      begin
        Timeout.timeout(zip_download_timeout) do
          loop do
            break if File.exist? receipt_file
            @sim_logger.info 'waiting for receipt file to appear'
            sleep 3
          end
        end

        @sim_logger.info 'receipt_file appeared, moving on'
        return true
      rescue ::Timeout::Error
        @sim_logger.error "Required analysis objects were not retrieved after #{zip_download_timeout} seconds."
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
          Timeout.timeout(360) do
            zip_download_count += 1
            File.open(download_file, 'wb') do |saved_file|
              # the following "open" is provided by open-uri
              open(download_url, 'rb') do |read_file|
                saved_file.write(read_file.read)
              end
            end
          end
        rescue => e
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
          Timeout.timeout(180) do
            extract_count += 1
            OpenStudio::Workflow.extract_archive(download_file, analysis_dir)
          end
        rescue => e
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
          Timeout.timeout(120) do
            json_download_count += 1
            a = RestClient.get analysis_json_url
            raise "Analysis JSON could not be downloaded - responce code of #{a.code} received." unless a.code == 200
            # Parse to JSON to save it again with nice formatting
            File.open(analysis_json_file, 'w') { |f| f << JSON.pretty_generate(JSON.parse(a)) }
          end
        rescue => e
          FileUtils.rm_f analysis_json_file if File.exist? analysis_json_file
          sleep Random.new.rand(1.0..10.0)
          retry if json_download_count < json_max_download_count
          raise "Downloading and extracting the analysis JSON failed #{json_max_download_count} with message #{e.message}"
        end

        # Now tell all other future data-points that it is okay to skip this step by creating the receipt file.
        File.open(receipt_file, 'w') { |f| f << Time.now }
      end

      # Run the server data_point initialization script with defined arguments, if it exists. Convert CRLF if required
      begin
        Timeout.timeout(600) do
          if File.directory? File.join(analysis_dir, 'scripts')
            files = Dir.glob("#{analysis_dir}/scripts/worker_initialization/*").select { |f| !f.match(/.*args$/) }.map { |f| File.basename(f) }
            files.each do |f|
              @sim_logger.info "Found data point initialization file #{f}."
              run_file(analysis_dir, 'initialization', f)
            end
          end
        end
      rescue => e
        raise "Error in data point initialization script: #{e.message} in #{e.backtrace.join("\n")}"
      end
    end

    @sim_logger.info 'Finished worker initialization'
    return true

  rescue => e
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

  def upload_file(filename, type, display_name = nil, content_type = nil)
    upload_file_attempt = 0
    upload_file_max_attempt = 4
    display_name = File.basename(filename, '.*') unless display_name
    @sim_logger.info "Saving report #{filename} to #{data_point_url}"
    begin
      Timeout.timeout(120) do
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
    rescue => e
      sleep Random.new.rand(1.0..10.0)
      retry if upload_file_attempt < upload_file_max_attempt
      @sim_logger.error "Could not save report #{display_name} with message: #{e.message} in #{e.backtrace.join("\n")}"
      return false
    end
  end

  # Run the initialize/finalize scripts
  def run_file(analysis_dir, state, file)
    f_fullpath = "#{analysis_dir}/scripts/worker_#{state}/#{file}"
    f_argspath = "#{File.dirname(f_fullpath)}/#{File.basename(f_fullpath, '.*')}.args"
    f_logpath = "#{run_dir}/#{File.basename(f_fullpath, '.*')}.log"

    # Make the file executable and remove DOS endings
    File.chmod(0777, f_fullpath)
    @sim_logger.info "Preparing to run #{state} script #{f_fullpath}"
    file_text = File.read(f_fullpath)
    file_text.gsub!(/\r\n/m, "\n")
    File.open(f_fullpath, 'wb') { |f| f.print file_text }

    # Check to see if there is an argument json that accompanies the class
    args = nil
    @sim_logger.info "Looking for argument file #{f_argspath}"
    if File.exist?(f_argspath)
      @sim_logger.info "argument file exists #{f_argspath}"
      #TODO replace eval with JSON.load
      args = eval(File.read(f_argspath))
      @sim_logger.info "arguments are #{args}"
    end

    # Spawn the process and wait for completion. Note only the specified env vars are available in the subprocess
    pid = spawn({'SCRIPT_ANALYSIS_ID' => @data_point.analysis.id, 'SCRIPT_DATA_POINT_ID' => @data_point.id},
                f_fullpath, *args, [:out, :err] => f_logpath, :unsetenv_others => true)
    Process.wait pid

    # Ensure the process exited with code 0
    exit_code = $?.exitstatus
    @sim_logger.info "Script returned with exit code #{exit_code} of class #{exit_code.class}"
    raise "Worker #{state} file #{file} returned with non-zero exit code. See #{f_logpath}." unless exit_code == 0
  end
end
