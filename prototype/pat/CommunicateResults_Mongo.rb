require 'openstudio'
require 'json'
require 'mongoid'
require 'mongoid_paperclip'
require 'socket'

def communicateStarted(data_point,directory)
  id = OpenStudio::removeBraces(data_point.uuid)
  dp = DataPoint.find_or_create_by(uuid: id)
  id = OpenStudio::removeBraces(data_point.analysisUUID.get)
  dp.analysis = Analysis.find_or_create_by(uuid: id)
  dp.values = data_point.variableValues.map{|v| v.toDouble}
  dp.ip_address = Socket.gethostname
  dp.status = "started"
  dp.save!  
end

def communicateResults(data_point,directory)  
  id = OpenStudio::removeBraces(data_point.uuid)

  # create zip file
  zipFilePath = directory / OpenStudio::Path.new("data_point_" + id + ".zip")
  zipFile = OpenStudio::ZipFile.new(zipFilePath,false)
  # TODO: Add files to ZipFile.
  
  # let mongo know that the data point is complete
  dp = DataPoint.find_or_create_by(uuid: id)
  data_point_options = OpenStudio::Analysis::DataPointSerializationOptions.new(directory.parent_path)
  dp.output = JSON.parse(data_point.toJSON(data_point_options))
  dp.status = "completed"
  dp.save!
end
