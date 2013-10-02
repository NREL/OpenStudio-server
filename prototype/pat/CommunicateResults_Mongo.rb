require 'openstudio'
require 'json'
require 'mongoid'
require 'mongoid_paperclip'
require 'socket'


def communicateStarted(id)
  dp = DataPoint.find_or_create_by(uuid: id)
  dp.status = "started"
  dp.ip_address = Socket.gethostname
  dp.save!
end


def getJSON(id, directory)

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

  # let mongo know that the data point is complete
  dp = DataPoint.find_or_create_by(uuid: id)
  data_point_options = OpenStudio::Analysis::DataPointSerializationOptions.new(directory.parent_path)
  json_output = JSON.parse(data_point.toJSON(data_point_options), :symbolize_names => true)
  dp.output = json_output

  # grab out the HTML and push it into mongo for the HTML display


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
  dp.status = "completed"
  dp.save!
end


def communicateFailure(id)
  dp = DataPoint.find_or_create_by(uuid: id)
  dp.status = "completed"
  dp.save!
end
