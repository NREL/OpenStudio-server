require 'openstudio'
require 'json'
require 'mongoid'
require 'mongoid_paperclip'
require 'socket'
require 'zlib'


def communicateStarted(id)
  dp = DataPoint.find_or_create_by(uuid: id)
  dp.status = "started"
  dp.run_start_time = Time.now
  dp.run_time_log = []
  dp.sdp_log_file = []

  if Socket.gethostname =~ /os-.*/
    # Maybe use this in the future: /sbin/ifconfig eth1|grep inet|head -1|sed 's/\:/ /'|awk '{print $3}'
    # Must be on vagrant and just use the hostname to do a lookup
    map = {"os-worker-1" => "192.168.33.11", "os-worker-2" => "192.168.33.12"}
    dp.ip_address = map[Socket.gethostname]
    dp.internal_ip_address = dp.ip_address
  else
    # On amazon, you have to hit an API to determine the IP address because
    # of the internal/external ip addresses

    public_ip_address = `curl -L http://169.254.169.254/latest/meta-data/public-ipv4`
    internal_ip_address = `curl -L http://169.254.169.254/latest/meta-data/local-ipv4`
    dp.ip_address = public_ip_address
    dp.internal_ip_address = internal_ip_address
  end

  dp.save!
end


def get_problem_json(id, directory)

  result = [] # [data_point_json, analysis_json]

  project_path = directory.parent_path.parent_path

  dp = DataPoint.find_or_create_by(uuid: id)
  data_point_hash = Hash.new
  data_point_hash[:data_point] = dp
  data_point_hash[:metadata] = dp[:os_metadata]
  result[0] = data_point_hash.to_json

  # DLM: temp debugging code
  #data_point_json_path = directory / OpenStudio::Path.new("data_point_in.json")
  #File.open(data_point_json_path.to_s, 'w') do |f|
  #  f.puts result[0]
  #end

  analysis = dp.analysis
  analysis_hash = Hash.new
  analysis_hash[:analysis] = analysis
  analysis_hash[:metadata] = analysis[:os_metadata]
  result[1] = analysis_hash.to_json

  # DLM: temp debugging code
  #formulation_json_path = directory / OpenStudio::Path.new("formulation.json")
  #File.open(formulation_json_path.to_s, 'w') do |f|
  #  f.puts result[1]
  #end

  return result
end


def communicateDatapoint(data_point)
  id = OpenStudio::removeBraces(data_point.uuid)
  dp = DataPoint.find_or_create_by(uuid: id)
  id = OpenStudio::removeBraces(data_point.analysisUUID.get)
  dp.analysis = Analysis.find_or_create_by(uuid: id)
  dp.values = data_point.variableValues.map { |v| v.toDouble }
  dp.save!
end

def communicate_debug_log(data_point_id, log_message)
  log_message = "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} UTC] #{log_message}"
  puts log_message
  dp = DataPoint.find_or_create_by(uuid: data_point_id)
  dp.sdp_log_file << log_message
  dp.save!

end

def communicate_time_log(data_point_id, log_message, prev_time = nil)
  dp = DataPoint.find_or_create_by(uuid: data_point_id)
  delta = 0
  if !prev_time.nil?
    delta = Time.now.to_f - prev_time.to_f
  end
  dp.run_time_log << "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} UTC] [Delta: #{delta.round(4)}s] #{log_message}"
  dp.save!
end

def communicateResults(data_point, directory)
  id = OpenStudio::removeBraces(data_point.uuid)

  # create zip file
  zipFilePath = directory / OpenStudio::Path.new("data_point_" + id + ".zip")
  zipFile = OpenStudio::ZipFile.new(zipFilePath, false)
  zipFile.addFile(directory / OpenStudio::Path.new("openstudio.log"), OpenStudio::Path.new("openstudio.log"))
  zipFile.addFile(directory / OpenStudio::Path.new("run.db"), OpenStudio::Path.new("run.db"))
  Dir.foreach(directory.to_s) do |item|
    next if item == '.' or item == '..'
    fullPath = directory / OpenStudio::Path.new(item)
    if File.directory?(fullPath.to_s)
      zipFile.addDirectory(fullPath, OpenStudio::Path.new(item))
    end
  end

  # save the datapoint results into the JSON field named output
  dp = DataPoint.find_or_create_by(uuid: id)
  data_point_options = OpenStudio::Analysis::DataPointSerializationOptions.new(directory.parent_path)
  json_output = JSON.parse(data_point.toJSON(data_point_options), :symbolize_names => true)
  #puts "JSON output is #{json_output}"
  #puts "JSON output is #{JSON.pretty_generate(json_output)}"

  # not sure what has changed here, but the data_point JSON from openstudio is no longer working
  dp.output = json_output

  # grab out the HTML and push it into mongo for the HTML display
  dir = File.join(directory.to_s)
  puts "analysis dir: #{dir}"
  eplus_html = Dir.glob("#{dir}/*EnergyPlus*/eplustbl.htm").last
  unless eplus_html.nil?
    puts "found html file #{eplus_html}"

    # compress and save into database, just use the system zip for now
    #compressed_string = Zlib::Deflate.deflate(eplus_html, Zlib::BEST_SPEED)
    #dp.eplus_html = compressed_string # `gzip -f -c  #{eplus_html}`
    dp.eplus_html = File.read(eplus_html)
    #dp.save!
  end

  # grab the %{uuid}.log file and jam it into the database
  #log_file = File.expand_path(File.join(directory.to_s,"../../#{id}.log"))
  #puts "log file is #{log_file}"
  #if File.exists?(log_file)
  #  puts "log file exists"
  #  puts File.read(log_file)
  #  dp.sdp_log_file = File.read(log_file)
  #end


  # parse the results flatter and persist into the results section
  #if !json_output.output.nil? && !json_output.output['data_point'].nil? && !json_output.output['data_point']['output_attributes'].nil?
  #  result_hash = {}
  #  json_output.output['data_point']['output_attributes'].each do |output_hash|
  #    unless output_hash['value_type'] == "AttributeVector"
  #      output_hash.has_key?('display_name') ? hash_key = output_hash['display_name'].parameterize.underscore :
  #          hash_key = output_hash['name'].parameterize.underscore
  #      logger.info("hash name will be: #{hash_key} with value: #{output_hash['value']}")
  #      result_hash[hash_key.to_sym] = output_hash['value']
  #    end
  #  end
  #  dp.results = result_hash
  #end

  dp.run_end_time = Time.now
  dp.status = "completed"
  dp.save!
end


def communicateFailure(id)
  dp = DataPoint.find_or_create_by(uuid: id)
  dp.status = "completed"
  dp.save!
end
