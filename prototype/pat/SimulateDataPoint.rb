
require 'openstudio'
require 'openstudio/energyplus/find_energyplus'
require 'optparse'
require 'json'

require 'mongoid'
require 'mongoid_paperclip'
require '/home/vagrant/mongoid/algorithm'
require '/home/vagrant/mongoid/analysis'
require '/home/vagrant/mongoid/data_point'
#require '/home/vagrant/mongoid/delayed_job_view'
require '/home/vagrant/mongoid/measure'
require '/home/vagrant/mongoid/problem'
require '/home/vagrant/mongoid/project'
require '/home/vagrant/mongoid/seed'
require '/home/vagrant/mongoid/variable'
require '/home/vagrant/mongoid/workflow_step'
require '/home/vagrant/mongoid/inflections'
require 'socket'


# parse arguments with optparse
options = Hash.new
optparse = OptionParser.new do |opts|

  opts.on( '-d', '--directory DIRECTORY', String, "Path to the directory that is pre-loaded with a DataPoint json." ) do |directory|
    options[:directory] = directory
  end
  
  options[:logLevel] = -1
  opts.on( '-l', '--logLevel LOGLEVEL', Integer, "Level of detail for project.log file. Trace = -3, Debug = -2, Info = -1, Warn = 0, Error = 1, Fatal = 2.") do |logLevel|
    options[:logLevel] = logLevel
  end  
  
end

optparse.parse!
if not options[:directory]
  # required argument is missing
  puts optparse
  exit
end

directory = OpenStudio::Path.new(options[:directory])
# on linux, if directory ends in /, need to call parent_path
if directory.stem.to_s == String.new
  directory = directory.parent_path
end
logLevel = options[:logLevel].to_i

project_path = directory.parent_path

# verify the existence of required files
data_point_json_path = directory / OpenStudio::Path.new("data_point_in.json")
formulation_json_path = project_path / OpenStudio::Path.new("formulation.json")
raise "Required file '" + data_point_json_path.to_s + "' does not exist." if not File.exist?(data_point_json_path.to_s)
raise "Required file '" + formulation_json_path.to_s + "' does not exist." if not File.exist?(formulation_json_path.to_s)

# set up log file
logSink = OpenStudio::FileLogSink.new(directory / OpenStudio::Path.new("openstudio.log"))
logSink.setLogLevel(logLevel)
OpenStudio::Logger::instance.standardOutLogger.disable

# load problem formulation
loadResult = OpenStudio::Analysis::loadJSON(formulation_json_path)
if loadResult.analysisObject.empty?
  loadResult.errors.each { |error|
    warn error.logMessage
  }
  raise "Unable to load json file from '" + formulation_json_path.to_s + "." 
end
analysis = loadResult.analysisObject.get.to_Analysis.get

# fix up paths
analysis.updateInputPathData(loadResult.projectDir,project_path)
analysis_options = OpenStudio::Analysis::AnalysisSerializationOptions.new(project_path)
analysis.saveJSON(directory / OpenStudio::Path.new("formulation_final.json"),analysis_options,true)

# load data point to run
loadResult = OpenStudio::Analysis::loadJSON(data_point_json_path)
if loadResult.analysisObject.empty?
  loadResult.errors.each { |error|
    warn error.logMessage
  }
  raise "Unable to load json file from '" + data_point_json_path.to_s + "."
end
data_point = loadResult.analysisObject.get.to_DataPoint.get
analysis.addDataPoint(data_point) # also hooks up real copy of problem

# create a RunManager
run_manager_path = directory / OpenStudio::Path.new("run.db")
run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_path,true,false,false)

# have problem create the workflow
workflow = analysis.problem.createWorkflow(data_point,OpenStudio::Path.new($OpenStudio_Dir));
params = OpenStudio::Runmanager::JobParams.new;
params.append("cleanoutfiles","standard");
workflow.add(params);
ep_hash = OpenStudio::EnergyPlus::find_energyplus(8,0)
ep_path = OpenStudio::Path.new(ep_hash[:energyplus_exe].to_s).parent_path
tools = OpenStudio::Runmanager::ConfigOptions::makeTools(ep_path,
                                                         OpenStudio::Path.new,
                                                         OpenStudio::Path.new,
                                                         $OpenStudio_RubyExeDir,
                                                         OpenStudio::Path.new)
workflow.add(tools)

# queue the RunManager job
url_search_paths = OpenStudio::URLSearchPathVector.new
weather_file_path = OpenStudio::Path.new
if (analysis.weatherFile)
  weather_file_path = analysis.weatherFile.get.path
end
job = workflow.create(directory,analysis.seed.path,weather_file_path,url_search_paths)
OpenStudio::Runmanager::JobFactory::optimizeJobTree(job)
analysis.setDataPointRunInformation(data_point, job, OpenStudio::PathVector.new);
run_manager.enqueue(job,false);

# wait for the job to finish
run_manager.waitForFinished

# use the completed job to populate data_point with results
analysis.problem.updateDataPoint(data_point,job)

# for now, print the final data point json
data_point_json_path = directory / OpenStudio::Path.new("data_point_out.json")
data_point_options = OpenStudio::Analysis::DataPointSerializationOptions.new(project_path)
data_point.saveJSON(data_point_json_path,data_point_options,true)

Mongoid.load!("/home/vagrant/mongoid/mongoid.yml", :development)
#puts data_point.toJSON(data_point_options)
puts data_point.uuid
data_point.variableValues.each {|value| puts value.toDouble}
puts data_point.analysisUUID.get

host = Socket.gethostname
puts host

#uuid = data_point.uuid
#uuidtrim = uuid[1...-2]
#puts uuidtrim
dp = DataPoint.find_or_create_by(uuid: data_point.uuid)
#dp = DataPoint.find_or_create_by(uuid: uuidtrim)
dp.analysis = Analysis.find_or_create_by(uuid: data_point.analysisUUID.get)
dp.output = JSON.parse(data_point.toJSON(data_point_options))
dp.values = data_point.variableValues.map{|v| v.toDouble}
dp.ip_address = host
dp.save!
