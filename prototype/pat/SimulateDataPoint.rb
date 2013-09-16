require 'openstudio'
require 'openstudio/energyplus/find_energyplus'
require 'optparse'

# parse arguments with optparse
options = Hash.new
optparse = OptionParser.new do |opts|

  opts.on('-d', '--directory DIRECTORY', String, "Path to the directory that is pre-loaded with a DataPoint json.") do |directory|
    options[:directory] = directory
  end

  opts.on('-r', '--runType RUNTYPE', String, "String that indicates where SimulateDataPoint is being run (Local|Vagrant|AWS).") do |runType|
    options[:runType] = runType
  end

  options[:logLevel] = -1
  opts.on('-l', '--logLevel LOGLEVEL', Integer, "Level of detail for project.log file. Trace = -3, Debug = -2, Info = -1, Warn = 0, Error = 1, Fatal = 2.") do |logLevel|
    options[:logLevel] = logLevel
  end

end

optparse.parse!
if not options[:directory]
  # required argument is missing
  puts optparse
  exit
end

# TODO: NL need to remove the concept of local and vagrant... perhaps make this is mixin, but that can be later
#       Need to have a handle to the datapoint record in mongo at all times in order to setup the status

runType = "Local"
if options[:runType]
  runType = options[:runType]
  if not ((runType == "Local") or (runType == "Vagrant") or (runType == "AWS"))
    puts optparse
    exit
  end
end

if (runType == "Vagrant")
  mongoid_path_prefix = '/home/vagrant/mongoid/'
elsif (runType == "AWS")
  mongoid_path_prefix = '/usr/local/lib/rails-models/'
  require 'delayed_job_mongoid'
end

if (runType == "Local")
  require "#{File.dirname(__FILE__)}/CommunicateResults_Local.rb"
else
  require "#{File.dirname(__FILE__)}/CommunicateResults_Mongo.rb"
  require mongoid_path_prefix + 'algorithm'
  require mongoid_path_prefix + 'analysis'
  require mongoid_path_prefix + 'data_point'
  require mongoid_path_prefix + 'measure'
  require mongoid_path_prefix + 'problem'
  require mongoid_path_prefix + 'project'
  require mongoid_path_prefix + 'seed'
  require mongoid_path_prefix + 'variable'
  require mongoid_path_prefix + 'workflow_step'
  require mongoid_path_prefix + 'inflections'
  Mongoid.load!(mongoid_path_prefix + "mongoid.yml", :development)
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
analysis.updateInputPathData(loadResult.projectDir, project_path)
analysis_options = OpenStudio::Analysis::AnalysisSerializationOptions.new(project_path)
analysis.saveJSON(directory / OpenStudio::Path.new("formulation_final.json"), analysis_options, true)

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
run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_path, true, false, false)

# have problem create the workflow
workflow = analysis.problem.createWorkflow(data_point, OpenStudio::Path.new($OpenStudio_Dir));
params = OpenStudio::Runmanager::JobParams.new;
params.append("cleanoutfiles", "standard");
workflow.add(params);
ep_hash = OpenStudio::EnergyPlus::find_energyplus(8, 0)
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
job = workflow.create(directory, analysis.seed.path, weather_file_path, url_search_paths)
OpenStudio::Runmanager::JobFactory::optimizeJobTree(job)
analysis.setDataPointRunInformation(data_point, job, OpenStudio::PathVector.new);
run_manager.enqueue(job, false);

# wait for the job to finish
run_manager.waitForFinished

# use the completed job to populate data_point with results
analysis.problem.updateDataPoint(data_point, job)

# TODO: revert this back to writing to mongo

# implemented differently for Local vs. Vagrant or AWS
communicateResults(data_point, directory)

