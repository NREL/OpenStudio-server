require 'openstudio'
require 'json'
require 'mongoid'
require 'mongoid_paperclip'
require 'socket'

def communicateResults(data_point,directory)
  host = Socket.gethostname
  puts host
  
  data_point_options = OpenStudio::Analysis::DataPointSerializationOptions.new(directory.parent_path)

  id = OpenStudio::removeBraces(data_point.uuid)
  puts id
  dp = DataPoint.find_or_create_by(uuid: id)
  id = OpenStudio::removeBraces(data_point.analysisUUID.get)
  puts id
  dp.analysis = Analysis.find_or_create_by(uuid: id)
  dp.output = JSON.parse(data_point.toJSON(data_point_options))
  dp.values = data_point.variableValues.map{|v| v.toDouble}
  dp.ip_address = host
  dp.status = "complete"
  dp.save!
end