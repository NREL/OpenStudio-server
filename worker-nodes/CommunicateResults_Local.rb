require 'openstudio'


def communicateStarted(id)
  puts "started"
end


def getJSON(id,directory)
  result = [] # [data_point_json, analysis_json]

  project_path = directory.parent_path.parent_path
  
  # verify the existence of required files
  data_point_json_path = directory / OpenStudio::Path.new("data_point_in.json")
  raise "Required file '" + data_point_json_path.to_s + "' does not exist." if not File.exist?(data_point_json_path.to_s)
  File.open(data_point_json_path.to_s, 'r') do |f|
    result[0] = f.read
  end
    
  formulation_json_path = project_path / OpenStudio::Path.new("formulation.json")
  raise "Required file '" + formulation_json_path.to_s + "' does not exist." if not File.exist?(formulation_json_path.to_s)
  File.open(formulation_json_path.to_s, 'r') do |f|
    result[1] = f.read
  end
  
  return result
end


def communicateDatapoint(data_point)

end


def communicateResults(data_point,directory)

  data_point_options = OpenStudio::Analysis::DataPointSerializationOptions.new(directory.parent_path)
  data_point_json_path = directory / OpenStudio::Path.new("data_point_out.json")
  data_point.saveJSON(data_point_json_path,data_point_options,true)

  puts "completed"
end


def communicateFailure(id)
  puts "failed"
end