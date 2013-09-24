require 'openstudio'
require 'openstudio/energyplus/find_energyplus'
require 'optparse'
require 'fileutils'

puts "Parsing Input"

# parse arguments with optparse
options = Hash.new
optparse = OptionParser.new do |opts|

  opts.on('-d', '--directory DIRECTORY', String, "Path to the directory that is pre-loaded with a DataPoint json.") do |directory|
    options[:directory] = directory
  end
  
  opts.on('-u', '--uuid UUID', String, "UUID of the data point to run with no braces.") do |uuid|
    options[:uuid] = uuid
  end
  
  opts.on('-r', '--runType RUNTYPE', String, "String that indicates where SimulateDataPoint is being run (Local|Vagrant|AWS).") do |runType|
    options[:runType] = runType
  end

  options[:logLevel] = -1
  opts.on('-l', '--logLevel LOGLEVEL', Integer, "Level of detail for project.log file. Trace = -3, Debug = -2, Info = -1, Warn = 0, Error = 1, Fatal = 2.") do |logLevel|
    options[:logLevel] = logLevel
  end

end

puts "Parsed Input"

optparse.parse!
if not options[:directory]
  # required argument is missing
  puts optparse
  exit
end

puts "Checking RunType"

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

puts "RunType is #{runType}"

if (runType == "Local")
  require "#{File.dirname(__FILE__)}/CommunicateResults_Local.rb"
else
  mongoid_path_prefix = '/mnt/openstudio/rails-models'
  require 'delayed_job_mongoid'
  require "#{File.dirname(__FILE__)}/CommunicateResults_Mongo.rb"
  Dir["#{mongoid_path_prefix}/*.rb"].each {|f| require f }
  Mongoid.load!(mongoid_path_prefix + "/mongoid.yml", :development)
end

directory = OpenStudio::Path.new(options[:directory])

project_path = directory.parent_path.parent_path

# on linux, if directory ends in /, need to call parent_path
if directory.stem.to_s == String.new
  directory = directory.parent_path
end
logLevel = options[:logLevel].to_i

puts "Directory is #{directory}"

# get data point uuid without braces
id = options[:uuid] # DLM: uuid as a parameter will be sent later, not currently available
if id.nil?
  if md = /data_point_(.*)/.match(directory.to_s)
    id = md[1]
  end
end

puts "Communicating Started #{id}"

# let listening processes know that this data point is running
communicateStarted(id)

begin

  if File.exist?(directory.to_s)
    puts "Deleting directory #{directory.to_s}"
    FileUtils.rm_rf(directory.to_s)
  end

  puts "Making directory #{directory.to_s}"
  
  # create data point directory
  FileUtils.mkdir_p(directory.to_s)
  
  # set up log file
  logSink = OpenStudio::FileLogSink.new(directory / OpenStudio::Path.new("openstudio.log"))
  logSink.setLogLevel(logLevel)
  OpenStudio::Logger::instance.standardOutLogger.disable
  
  puts "Getting JSON input"
  
  # get json from database
  json = getJSON(id,directory)
  data_point_json = json[0]
  analysis_json = json[1]
  
  puts "Parsing Analysis JSON input"

  # load problem formulation
  loadResult = OpenStudio::Analysis::loadJSON(analysis_json)
  if loadResult.analysisObject.empty?
    loadResult.errors.each { |error|
      warn error.logMessage
    }
    raise "Unable to load analysis json."
  end
  analysis = loadResult.analysisObject.get.to_Analysis.get

  # fix up paths
  analysis.updateInputPathData(loadResult.projectDir, project_path)
  analysis_options = OpenStudio::Analysis::AnalysisSerializationOptions.new(project_path)
  analysis.saveJSON(directory / OpenStudio::Path.new("formulation_final.json"), analysis_options, true)

  puts "Parsing DataPoint JSON input"
  
  # load data point to run
  loadResult = OpenStudio::Analysis::loadJSON(data_point_json)
  if loadResult.analysisObject.empty?
    loadResult.errors.each { |error|
      warn error.logMessage
    }
    raise "Unable to load data point json."
  end
  data_point = loadResult.analysisObject.get.to_DataPoint.get
  analysis.addDataPoint(data_point) # also hooks up real copy of problem
  
  puts "Communicating DataPoint"

  # update datapoint in database
  communicateDatapoint(data_point)

  puts "Running Simulation"
  
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
  
  # DLM: Elaine somehow we need to add info to data point to avoid this error:
  # [openstudio.analysis.AnalysisObject] <1> The json string cannot be parsed as an
  # OpenStudio analysis framework json file, because Unable to find ToolInfo object
  # at expected location.

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

  puts "Waiting for simulation to finish"
  
  # wait for the job to finish
  run_manager.waitForFinished
  
  puts "Simulation finished"

  # use the completed job to populate data_point with results
  analysis.problem.updateDataPoint(data_point, job)
  
  puts "Communicating Results"

  # implemented differently for Local vs. Vagrant or AWS
  communicateResults(data_point, directory)
  
rescue Exception

  puts "Communicating Failure"

  # need to tell mongo this failed 
  communicateFailure(id)
  
  # raise last exception
  raise
end

puts "Complete"

# DLM: this is where we put the objective functions
puts "0"
