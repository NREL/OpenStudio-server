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


def getJSON(id,directory)

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
  dp.values = data_point.variableValues.map{|v| v.toDouble}
  dp.save!  
end


def communicateResults(data_point,directory)  
  id = OpenStudio::removeBraces(data_point.uuid)

  # create zip file
  zipFilePath = directory / OpenStudio::Path.new("data_point_" + id + ".zip")
  zipFile = OpenStudio::ZipFile.new(zipFilePath,false)
  zipFile.addFile(directory / OpenStudio::Path.new("openstudio.log"),
                  OpenStudio::Path.new("openstudio.log"))
  zipFile.addFile(directory / OpenStudio::Path.new("run.db"),
                  OpenStudio::Path.new("run.db"))
  Dir.foreach(directory.to_s) do |item|
    next if item == '.' or item == '..'
    fullPath = directory / OpenStudio::Path.new(item)
    if File.directory?(fullPath.to_s)
      zipFile.addDirectory(fullPath,OpenStudio::Path.new(item))
    end    
  end
  
  # let mongo know that the data point is complete
  dp = DataPoint.find_or_create_by(uuid: id)
  data_point_options = OpenStudio::Analysis::DataPointSerializationOptions.new(directory.parent_path)
  dp.output = JSON.parse(data_point.toJSON(data_point_options))
  dp.status = "completed"
  dp.save!
end


def communicateFailure(id)
  dp = DataPoint.find_or_create_by(uuid: id)
  dp.status = "completed"
  dp.save!  
end
