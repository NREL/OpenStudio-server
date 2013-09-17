require 'openstudio'

def communicateStarted(data_point,directory)

end

def communicateResults(data_point,directory)

  data_point_options = OpenStudio::Analysis::DataPointSerializationOptions.new(directory.parent_path)

  data_point_json_path = directory / OpenStudio::Path.new("data_point_out.json")
  data_point.saveJSON(data_point_json_path,data_point_options,true)

end