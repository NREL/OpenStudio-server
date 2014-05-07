require 'json'

module CommunicateMongo
  def self.communicate_started(dp)
    dp.status = 'started'
    dp.status_message = ''
    dp.run_start_time = Time.now

    # Todo use the ComputeNode model to pull out the information so that we can reuse the methods

    # Determine what the IP address is of the worker node and save in the data point
    require 'socket'
    if Socket.gethostname =~ /os-.*/
      # Maybe use this in the future: /sbin/ifconfig eth1|grep inet|head -1|sed 's/\:/ /'|awk '{print $3}'
      # Must be on vagrant and just use the hostname to do a lookup
      map = { 'os-server' => '192.168.33.10', 'os-worker-1' => '192.168.33.11', 'os-worker-2' => '192.168.33.12' }
      dp.ip_address = map[Socket.gethostname]
      dp.internal_ip_address = dp.ip_address

      # TODO: add back in the instance id
    else
      # On amazon, you have to hit an API to determine the IP address because
      # of the internal/external ip addresses

      # NL: add the suppress
      public_ip_address = `curl -sL http://169.254.169.254/latest/meta-data/public-ipv4`
      internal_ip_address = `curl -sL http://169.254.169.254/latest/meta-data/local-ipv4`
      # instance_information = `curl -sL http://169.254.169.254/latest/meta-data/instance-id`
      # instance_information = `curl -sL http://169.254.169.254/latest/meta-data/ami-id`
      dp.ip_address = public_ip_address
      dp.internal_ip_address = internal_ip_address
      # dp.server_information = instance_information
    end

    dp.save!
  end

  def self.get_datapoint(id)
    # TODO : make this a conditional on when to create one vs when to error out.
    DataPoint.find_or_create_by(uuid: id)
  end

  def self.get_problem(dp, format)
    analysis = dp.analysis

    data_point_hash = {}
    analysis_hash = {}
    if analysis
      data_point_hash[:data_point] = dp
      data_point_hash[:openstudio_version] = analysis[:openstudio_version]

      analysis_hash[:analysis] = analysis
      analysis_hash[:openstudio_version] = analysis[:openstudio_version]
    end

    if format == 'hash'
      [data_point_hash, analysis_hash]
    else
      [data_point_hash.to_json, analysis_hash.to_json]
    end
  end

  def self.communicate_log_message(dp, log_message, add_delta_time = false, prev_time = nil)
    if add_delta_time
      delta = 0
      if prev_time
        delta = Time.now.to_f - prev_time.to_f
      end
      log_message = "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} UTC] [Delta: #{delta.round(4)}s] #{log_message}"
    else
      log_message = "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} UTC] #{log_message}"
    end

    puts log_message # print the message to screen
    dp.sdp_log_file ||= []
    dp.sdp_log_file << log_message
    dp.save!
  end

  def self.communicate_results(dp, os_data_point, os_directory)
    os_directory = os_directory.to_s
    zip_results(dp, os_directory, 'runmanager')

    # save the datapoint results into the JSON field named output
    json_output = JSON.parse(os_data_point.toJSON, symbolize_names: true)
    dp.output = json_output

    dp.save! # redundant because next method calls save too.
  end

# report intermediate results to the database (typically these are measure initial and final values)
  def self.communicate_intermediate_result(dp, h)
    if h
      dp.results ? dp.results.merge!(h) : dp.results = h
      dp.save!
    end
  end

  def self.communicate_results_json(dp, eplus_json, analysis_dir)
    zip_results(dp, analysis_dir, 'workflow')

    communicate_log_message dp, 'Saving EnergyPlus JSON file'
    if eplus_json
      dp.results ? dp.results.merge!(eplus_json) : dp.results = eplus_json
    end
    result = dp.save! # redundant because next method calls save too.
    if result
      communicate_log_message dp, 'Successfully saved result to database'
    else
      communicate_log_message dp, 'ERROR saving result to database'
    end
  end

  def self.communicate_complete(dp)
    dp.run_end_time = Time.now
    dp.status = 'completed'
    dp.status_message = 'completed normal'
    dp.save!
  end

  # Zip up the results if analysis_dir is passed. Send the status to MongoDB
  def self.communicate_failure(dp, analysis_dir)
    # zip up the folder even on datapoint failures
    if analysis_dir && File.exist?(analysis_dir)
      zip_results(dp, analysis_dir)
    end

    dp.run_end_time = Time.now
    dp.status = 'completed'
    dp.status_message = 'datapoint failure'
    dp.save!
  end

  def self.reload(dp)
    dp.reload
  end

  def self.zip_results(dp, analysis_dir, analysis_type = 'workflow')
    eplus_search_path = nil
    current_dir = Dir.pwd
    FileUtils.mkdir_p "#{analysis_dir}/reports"
    case analysis_type
      when 'workflow'
        eplus_search_path = "#{analysis_dir}/*run*/eplustbl.htm"
      when 'runmanager'
        eplus_search_path = "#{analysis_dir}/*EnergyPlus*/eplustbl.htm"
    end

    # copy some files into a report folder
    eplus_html = Dir.glob(eplus_search_path).last || nil
    if eplus_html
      communicate_log_message dp, "Checking for HTML Report: #{eplus_html}"
      if File.exist? eplus_html
        # do some encoding on the html if possible
        html = File.read(eplus_html)
        html = html.force_encoding('ISO-8859-1').encode('utf-8', replace: nil)
        File.open("#{analysis_dir}/reports/eplustbl.html", 'w') { |f| f << html }
      end
    end

    # create zip file using a system call
    communicate_log_message dp, "Zipping up Analysis Directory #{analysis_dir}"
    if File.directory? analysis_dir
      Dir.chdir(analysis_dir)
      `zip -9 -r --exclude=*.rb* data_point_#{dp.uuid}.zip .`
    end

    # zip up only the reports folder
    report_dir = "#{analysis_dir}"
    communicate_log_message dp, "Zipping up Analysis Reports Directory #{report_dir}/reports"
    if File.directory? report_dir
      Dir.chdir(report_dir)
      `zip -r data_point_#{dp.uuid}_reports.zip reports`
    end
    Dir.chdir(current_dir)
  end
end
