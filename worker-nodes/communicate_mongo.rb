require 'openstudio' # TODO: remove openstudio as a dependency of this script.  
require 'json'
require 'zlib' # for compressing html

module CommunicateMongo
  def self.communicate_started(dp)
    dp.status = "started"
    dp.status_message = ""
    dp.run_start_time = Time.now

    # Todo use the ComputeNode model to pull out the information so that we can reuse the methods
    
    # Determine what the IP address is of the worker node and save in the data point
    require 'socket'
    if Socket.gethostname =~ /os-.*/
      # Maybe use this in the future: /sbin/ifconfig eth1|grep inet|head -1|sed 's/\:/ /'|awk '{print $3}'
      # Must be on vagrant and just use the hostname to do a lookup
      map = {"os-server" => "192.168.33.10", "os-worker-1" => "192.168.33.11", "os-worker-2" => "192.168.33.12"}
      dp.ip_address = map[Socket.gethostname]
      dp.internal_ip_address = dp.ip_address
      
      #TODO: add back in the instance id 
    else
      # On amazon, you have to hit an API to determine the IP address because
      # of the internal/external ip addresses

      # NL: add the suppress 
      public_ip_address = `curl -sL http://169.254.169.254/latest/meta-data/public-ipv4`
      internal_ip_address = `curl -sL http://169.254.169.254/latest/meta-data/local-ipv4`
      #instance_information = `curl -sL http://169.254.169.254/latest/meta-data/instance-id`
      #instance_information = `curl -sL http://169.254.169.254/latest/meta-data/ami-id`
      dp.ip_address = public_ip_address
      dp.internal_ip_address = internal_ip_address
      #dp.server_information = instance_information
    end

    dp.save!
  end

  def self.get_problem(dp, format)
    analysis = dp.analysis
  
    data_point_hash = Hash.new
    data_point_hash[:data_point] = dp
    data_point_hash[:openstudio_version] = analysis[:openstudio_version]

    analysis_hash = Hash.new
    analysis_hash[:analysis] = analysis
    analysis_hash[:openstudio_version] = analysis[:openstudio_version]

    result = nil
    if format == "hash"
      [data_point_hash, analysis_hash]
    else
      [data_point_hash.to_json, analysis_hash.to_json]
    end
  end

  def self.communicate_log_message(dp, log_message, add_delta_time=false, prev_time=nil)
    if add_delta_time
      delta = 0
      if prev_time
        delta = Time.now.to_f - prev_time.to_f
      end
      log_message = "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} UTC] [Delta: #{delta.round(4)}s] #{log_message}"
    else
      log_message = "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} UTC] #{log_message}"
    end

    puts log_message #print the message to screen
    dp.sdp_log_file ||= []
    dp.sdp_log_file << log_message
    dp.save!
  end

  def self.communicate_results(dp, os_data_point, os_directory)
    # create zip file
    # TODO: remove openstudio here and put the work back on the run_openstudio script
    zipFilePath = os_directory / OpenStudio::Path.new("data_point_" + dp.uuid + ".zip")
    zipFile = OpenStudio::ZipFile.new(zipFilePath, false)
    zipFile.addFile(os_directory / OpenStudio::Path.new("openstudio.log"), OpenStudio::Path.new("openstudio.log"))
    zipFile.addFile(os_directory / OpenStudio::Path.new("run.db"), OpenStudio::Path.new("run.db"))
    Dir.foreach(os_directory.to_s) do |item|
      next if item == '.' or item == '..'
      fullPath = os_directory / OpenStudio::Path.new(item)
      if File.directory?(fullPath.to_s)
        zipFile.addDirectory(fullPath, OpenStudio::Path.new(item))
      end
    end

    # save the datapoint results into the JSON field named output
    json_output = JSON.parse(os_data_point.toJSON(), :symbolize_names => true)
    dp.output = json_output

    # grab out the HTML and push it into mongo for the HTML display
    dir = File.join(os_directory.to_s)
    puts "analysis dir: #{dir}"
    eplus_html = Dir.glob("#{dir}/*EnergyPlus*/eplustbl.htm").last
    if eplus_html
      puts "found html file #{eplus_html}"

      # compress and save into database, just use the system zip for now
      #compressed_string = Zlib::Deflate.deflate(eplus_html, Zlib::BEST_SPEED)
      #dp.eplus_html = compressed_string # `gzip -f -c  #{eplus_html}`
      dp.eplus_html = File.read(eplus_html)
      #dp.save!
    end
    dp.save! # redundant because next method calls save too.
  end

  def self.communicate_results_json(dp, eplus_json, analysis_dir)
    # create zip file using a system call
    current_dir = Dir.pwd
    Dir.chdir(analysis_dir)
    `zip -r data_point_#{dp.uuid}.zip .`
    Dir.chdir(current_dir)

    # grab out the HTML and push it into mongo for the HTML display
    puts "analysis dir: #{analysis_dir}"
    eplus_html = Dir.glob("#{analysis_dir}/*run*/eplustbl.htm").last
    if eplus_html
      puts "found html file #{eplus_html}"

      # compress and save into database, just use the system zip for now
      #compressed_string = Zlib::Deflate.deflate(eplus_html, Zlib::BEST_SPEED)
      #dp.eplus_html = compressed_string # `gzip -f -c  #{eplus_html}`
      dp.eplus_html = File.read(eplus_html)
      #dp.save!
    end

    if eplus_json
      dp.results = eplus_json
    end
    dp.save! # redundant because next method calls save too.

  end

  def self.communicate_complete(dp)
    dp.run_end_time = Time.now
    dp.status = "completed"
    dp.status_message = "completed normal"
    dp.save!
  end

  def self.communicate_failure(dp)
    dp.run_end_time = Time.now
    dp.status = "completed"
    dp.status_message = "datapoint failure"
    dp.save!
  end

  def self.reload(dp)
    dp.reload
  end

end


