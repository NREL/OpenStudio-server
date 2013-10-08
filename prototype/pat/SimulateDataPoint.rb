require 'openstudio'
require 'openstudio/energyplus/find_energyplus'
require 'optparse'
require 'fileutils'

puts "Parsing Input: #{ARGV.inspect}"

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

optparse.parse!
puts "Parsed Input: #{optparse}"

puts "Checking Arguments"
if not options[:directory]
  # required argument is missing
  puts optparse
  exit
end


puts "Checking UUID of #{options[:uuid]}"
if (not options[:uuid]) || (options[:uuid] == "NA")
  puts "No UUID defined"
  if options[:uuid] == "NA"
    puts "Recevied an NA UUID which may be because you are only trying to run one datapoint"
  end
  exit
end

puts "Checking RunType"
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
  Dir["#{mongoid_path_prefix}/*.rb"].each { |f| require f }
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
communicate_time_log(id, "started")

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

  puts "Getting Problem JSON input"
  communicate_time_log(id, "Getting Problem JSON from database")

  # get json from database
  json = get_problem_json(id, directory)
  data_point_json = json[0]
  analysis_json = json[1]

  puts "Parsing Analysis JSON input"
  communicate_time_log(id, "Reading Problem JSON into OpenStudio")
  # load problem formulation
  loadResult = OpenStudio::Analysis::loadJSON(analysis_json)
  if loadResult.analysisObject.empty?
    loadResult.errors.each { |error|
      warn error.logMessage
    }
    raise "Unable to load analysis json."
  end

  communicate_time_log(id, "Get Analysis From OpenStudio")
  analysis = loadResult.analysisObject.get.to_Analysis.get

  # fix up paths
  communicate_time_log(id, "Fix Paths")
  analysis.updateInputPathData(loadResult.projectDir, project_path)
  analysis_options = OpenStudio::Analysis::AnalysisSerializationOptions.new(project_path)
  analysis.saveJSON(directory / OpenStudio::Path.new("formulation_final.json"), analysis_options, true)

  puts "Parsing DataPoint JSON input"
  communicate_time_log(id, "Load DataPoint JSON")

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
  communicate_time_log(id, "Update DataPoint Database Record")

  # update datapoint in database
  communicateDatapoint(data_point)

  puts "Running Simulation"
  communicate_time_log(id, "Setting Up RunManager")

  # create a RunManager
  run_manager_path = directory / OpenStudio::Path.new("run.db")
  run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_path, true, false, false)

  # have problem create the workflow
  communicate_time_log(id, "Creating Workflow")
  workflow = analysis.problem.createWorkflow(data_point, OpenStudio::Path.new($OpenStudio_Dir));
  params = OpenStudio::Runmanager::JobParams.new;
  params.append("cleanoutfiles", "standard");
  workflow.add(params);
  ep_hash = OpenStudio::EnergyPlus::find_energyplus(8, 0)
  raise "SimulateDataPoint.rb was unable to locate EnergyPlus." if ep_hash.nil?
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
  communicate_time_log(id, "Queue RunManager Job")
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
  communicate_time_log(id, "Starting Simulation")

  # wait for the job to finish
  #run_manager.waitForFinished

  # Get some introspection on what the current running job is. For now just
  # look at the directories that are being generated
  job_dirs = []
  prev_time = nil
  while run_manager.workPending()
    sleep 5
    OpenStudio::Application::instance().processEvents()

    # check if there are any new folders that were creates
    temp_dirs = Dir[File.join(directory.to_s,"*/")].map { |d| d.split("/").pop}.sort
    if (temp_dirs + job_dirs).uniq != job_dirs
      communicate_time_log(id, (temp_dirs - job_dirs).join(","), prev_time)
      job_dirs = temp_dirs
      prev_time = Time.now
    end
  end

  puts "Simulation finished"
  communicate_time_log(id, "Simulation Finished")

  # use the completed job to populate data_point with results
  communicate_time_log(id, "Updating OpenStudio DataPoint object")
  analysis.problem.updateDataPoint(data_point, job)


  puts "Communicating Results"
  communicate_time_log(id, "Communicating the results back to Server")

  # implemented differently for Local vs. Vagrant or AWS
  communicateResults(data_point, directory)

rescue Exception => e
  puts "SimulationDataPoint Script failed"
  puts e.message
  puts e.backtrace

  # need to tell mongo this failed
  communicateFailure(id)

  # raise last exception
  # raise  #NL: Don't raise an exception because this will be sent to R and it will not know how to process it.
end

puts "Complete"

# DLM: this is where we put the objective functions.  NL: Note that we must return out of this nicely no matter what.
puts "0"
