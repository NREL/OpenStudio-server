require 'openstudio'

require 'rubygems'
require 'json'
require 'orderedhash'

def print_uuid(uuid)
  return uuid.to_s.gsub('}','').gsub('{','')
end

OpenStudio::Application::instance::application

pat_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/PATTest")

project = OpenStudio::AnalysisDriver::SimpleProject::open(pat_path).get

analysis = project.analysis

problem = analysis.problem

variables = problem.variables

seed_data_point = analysis.dataPoints[0]

variables_array = []
variables.each_index do |i|
  variable = variables[i]
  
  variable_hash = OrderedHash.new
  variable_hash["variable_index"] = i
  variable_hash["uuid"] = print_uuid(variable.uuid)
  variable_hash["version_uuid"] = print_uuid(variable.versionUUID)
  variable_hash["name"] = variable.name
  variable_hash["display_name"] = variable.displayName
  
  discrete_perturbation = variable.to_DiscreteVariable.get

  # DLM: do we want only selected perturbations?  Would this be better as an enum?
  perturbations = discrete_perturbation.perturbations(false)
  
  variable_hash["type"] = "Integer"
  variable_hash["minimum"] = 0
  variable_hash["maximum"] = perturbations.size - 1
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

#########################################################

datapoints = analysis.dataPoints

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

