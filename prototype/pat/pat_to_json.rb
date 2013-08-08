require 'openstudio'

require 'rubygems'
require 'json'
require 'orderedhash'

def print_uuid(uuid)
  return uuid.to_s.gsub('}','').gsub('{','')
end

# Open and retrieve data from example project
OpenStudio::Application::instance::application
pat_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/PATTest")
project = OpenStudio::AnalysisDriver::SimpleProject::open(pat_path).get
analysis = project.analysis
problem = analysis.problem
variables = problem.variables
seed_data_point = analysis.dataPoints[0]
datapoints = analysis.dataPoints

# Print server views ###########################################################

# server_problem.json
variables_array = []
variables.each_index do |i|
  variable = variables[i]
  
  variable_hash = OrderedHash.new
  variable_hash["variable_index"] = i
  variable_hash["uuid"] = print_uuid(variable.uuid)
  variable_hash["version_uuid"] = print_uuid(variable.versionUUID)
  variable_hash["name"] = variable.name
  variable_hash["display_name"] = variable.displayName
  
  measure_group = variable.to_MeasureGroup.get

  # DLM: do we want only selected measures?  Would this be better as an enum?
  measures = measure_group.measures(false)
  
  variable_hash["type"] = "Integer"
  variable_hash["minimum"] = 0
  variable_hash["maximum"] = measures.size - 1
  variable_hash["initial_value"] = seed_data_point.variableValues[i].toInt

  variables_array << variable_hash
end

result_hash = OrderedHash.new
result_hash["variables"] = variables_array

result = JSON.pretty_generate(result_hash)
puts result
File.open('server_problem.json', 'w') do |file|
  file.puts result
end

# server_datapoints_request.json

datapoints_array = []
datapoints.each do |data_point|
  data_point_hash = OrderedHash.new
  data_point_hash["uuid"] = print_uuid(data_point.uuid)
  data_point_hash["version_uuid"] = print_uuid(data_point.versionUUID)
  data_point_hash["name"] = data_point.name
  data_point_hash["display_name"] = data_point.displayName
  
  values = []
  variable_values = data_point.variableValues
  variable_values.each_index do |i|
    variable_value = variable_values[i]
    
    variable_value_hash = OrderedHash.new
    variable_value_hash["variable_index"] = i
    variable_value_hash["variable_uuid"] = print_uuid(variables[i].uuid)
    variable_value_hash["value"] = variable_value.toInt
    values << variable_value_hash
  end
  data_point_hash["values"] = values
  
  datapoints_array << data_point_hash
end

result_hash = OrderedHash.new
result_hash["datapoints"] = datapoints_array

result = JSON.pretty_generate(result_hash)
puts result
File.open('server_datapoints_request.json', 'w') do |file|
  file.puts result
end

# Create and populate folders for individual DataPoint runs ####################

require 'fileutils'

# Set up project folder and files
project_dir_name = "analysis_" + print_uuid(analysis.uuid)
if File.exist?(project_dir_name)
  FileUtils.rm_rf(project_dir_name)
end
FileUtils.mkdir(project_dir_name)
project_dir_path = OpenStudio::Path.new(project_dir_name)
#
# ETH@20130808: The following code should be replaced by some sort of .tar.gz export of SimpleProject
# that is called and posted to openstudio-server by the RemoteAnalysisDriver. 
#
# seed.osm and seed/files/
FileUtils.cp(project.seed.path.to_s,(project_dir_path / OpenStudio::Path.new("seed.osm")).to_s)
FileUtils.mkdir((project_dir_path / OpenStudio::Path.new("seed")).to_s)
FileUtils.cp_r((project.seed.path.parent_path / 
                OpenStudio::Path.new(project.seed.path.stem) / 
                OpenStudio::Path.new("files")).to_s,
               (project_dir_path / OpenStudio::Path.new("seed/files")).to_s)
# scripts
FileUtils.cp_r((pat_path / OpenStudio::Path.new("scripts")).to_s,
               (project_dir_path / OpenStudio::Path.new("scripts")).to_s)
# problem formulation
formulation_json_path = project_dir_path / OpenStudio::Path.new("formulation.json")
analysis.saveJSON(formulation_json_path,"ProblemFormulation".to_AnalysisSerializationScope)

# Set up run folders and files
datapoints.each do |data_point|

  data_point_dir_name = "data_point_" + print_uuid(data_point.uuid)
  data_point_dir_path = project_dir_path / OpenStudio::Path.new(data_point_dir_name)
  FileUtils.mkdir(data_point_dir_path.to_s)
  
  data_point_json_path = data_point_dir_path / OpenStudio::Path.new("data_point_in.json")  
  data_point.saveJSON(data_point_json_path)  
  
end
