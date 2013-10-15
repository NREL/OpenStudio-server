require 'openstudio'
require 'openstudio/energyplus/find_energyplus'
require 'optparse'
require 'fileutils'

puts "Parsing Input: #{ARGV.inspect}"

# parse arguments with optparse
options = Hash.new
optparse = OptionParser.new do |opts|

  opts.on('-d', '--directory DIRECTORY', String, "Path to the directory will run the Data Point.") do |directory|
    options[:directory] = directory
  end

  opts.on('-u', '--uuid UUID', String, "UUID of the data point to run with no braces.") do |uuid|
    options[:uuid] = uuid
  end

  options[:runType] = "AWS"
  opts.on('-r', '--runType RUNTYPE', String, "String that indicates where Simulate Data Point is being run (Local|AWS).") do |runType|
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

# TODO: The first thing this needs to do is register itself with the server to get the datapoint information
# This also needs to only create one handle to the datapoint database object, then use that instead of hitting the
# database to find the right record each time it wants to say something.

puts "Checking UUID of #{options[:uuid]}"
if (not options[:uuid]) || (options[:uuid] == "NA")
  puts "No UUID defined"
  if options[:uuid] == "NA"
    puts "Recevied an NA UUID which may be because you are only trying to run one datapoint"
  end
  exit
end





     # STUBS

require 'rotate/measure.rb'
infil =

    # create an instance of the measure
    measure = RotateBuilding.new

# create an instance of a runner
runner = OpenStudio::Ruleset::OSRunner.new

# make an empty model
model = OpenStudio::Model::Model.new

# get arguments and test that they are what we are expecting
arguments = measure.arguments(model)
assert_equal(1, arguments.size)
assert_equal("relative_building_rotation", arguments[0].name)

# load the test model
translator = OpenStudio::OSVersion::VersionTranslator.new
path = OpenStudio::Path.new(File.dirname(__FILE__) + "/RotateBuilding_TestModel_01.osm")
model = translator.loadModel(path)
assert((not model.empty?))
model = model.get

# set argument values to good values and run the measure on model with spaces
arguments = measure.arguments(model)
argument_map = OpenStudio::Ruleset::OSArgumentMap.new

relative_building_rotation = arguments[0].clone
assert(relative_building_rotation.setValue("500.2"))
argument_map["relative_building_rotation"] = relative_building_rotation

measure.run(model, runner, argument_map)
result = runner.result
show_output(result)
assert(result.value.valueName == "Success")
assert(result.warnings.size == 2)
assert(result.info.size == 1)
















puts "Checking RunType"
runType = options[:runType] if options[:runType]

puts "RunType is #{runType}"

if (runType == "Local")
  require "#{File.dirname(__FILE__)}/CommunicateResults_Local.rb"
else
  mongoid_path_prefix = '/mnt/openstudio/rails-models'
  require 'delayed_job_mongoid'
  require "/mnt/openstudio/CommunicateResults_Mongo.rb"
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

# let listening processes know that this data point is running
communicateStarted(id)
communicate_debug_log(id, "Communicating Started #{id}")
communicate_time_log(id, "started")

begin
  communicate_debug_log(id, "Making directory #{directory.to_s}")

  # set up log file
  logSink = OpenStudio::FileLogSink.new(directory / OpenStudio::Path.new("openstudio.log"))
  logSink.setLogLevel(logLevel)
  OpenStudio::Logger::instance.standardOutLogger.disable

  communicate_debug_log(id, "Getting Problem JSON input")
  communicate_time_log(id, "Getting Problem JSON from database")

  # get json from database
  json = get_problem_json(id, directory)
  data_point_json = json[0]
  analysis_json = json[1]

  # DIVERGE HERE

  # Get database point by index of manipulation (THIS IS NOT YET KNOWN)



  communicate_debug_log(id, "Parsing Analysis JSON input")
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

  communicate_debug_log(id, "Parsing DataPoint JSON input")
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

  communicate_debug_log(id, "Communicating DataPoint")
  communicate_time_log(id, "Update DataPoint Database Record")

  # update datapoint in database
  communicateDatapoint(data_point)

  communicate_debug_log(id, "Running Simulation")
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
  raise "#{File.basename(__FILE__)} was unable to locate EnergyPlus." if ep_hash.nil?
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

  communicate_debug_log(id,"Waiting for simulation to finish")
  communicate_time_log(id, "Starting Simulation")

  # wait for the job to finish
  #run_manager.waitForFinished

  # Get some introspection on what the current running job is. For now just
  # look at the directories that are being generated
  job_dirs = []
  prev_time = nil
  while run_manager.workPending()
    sleep 2
    OpenStudio::Application::instance().processEvents()

    # check if there are any new folders that were creates
    temp_dirs = Dir[File.join(directory.to_s, "*/")].map { |d| d.split("/").pop }.sort
    if (temp_dirs + job_dirs).uniq != job_dirs
      communicate_time_log(id, (temp_dirs - job_dirs).join(","), prev_time)
      job_dirs = temp_dirs
      prev_time = Time.now
    end
  end

  # skip the energyplus method and force it here

  # now force enerygplus to run
=begin
  communicate_time_log(id, "running custom energyplus process")
  dest_dir = "#{directory.to_s}/99_EnergyPlus"
  FileUtils.mkdir_p(dest_dir)
  #can't create symlinks because the /vagrant mount is actually a windows mount
  FileUtils.copy("/usr/local/EnergyPlus-8-0-0/EnergyPlus", "#{dest_dir}/EnergyPlus")
  FileUtils.copy("/usr/local/EnergyPlus-8-0-0/Energy+.idd", "#{dest_dir}/Energy+.idd")
  # get the first energyplus file
  idf = Dir.glob("#{directory.to_s}/*-EnergyPlusPreProcess-*/*.idf").first
  communicate_time_log(id, "idf is #{idf}")
  FileUtils.copy(idf, "#{dest_dir}/in.idf")
  epw = Dir.glob("#{directory.to_s}/*-UserScript-*/**/*.epw").first
  communicate_time_log(id, "epw is #{epw}")
  FileUtils.copy(epw, "#{dest_dir}/in.epw")
  Dir.chdir(dest_dir)

  #create stdout
  File.open('stdout','w') do |file|
    IO.popen('EnergyPlus') { |io| while (line = io.gets) do file << line end }
  end
=end

  communicate_debug_log(id, "Simulation finished")
  communicate_time_log(id, "Simulation Finished")

  # use the completed job to populate data_point with results
  communicate_time_log(id, "Updating OpenStudio DataPoint object")
  analysis.problem.updateDataPoint(data_point, job)


  communicate_debug_log(id, "Communicating Results")
  communicate_time_log(id, "Communicating the results back to Server")

  # implemented differently for Local vs. Vagrant or AWS
  communicateResults(data_point, directory)

rescue Exception => e
  communicate_debug_log(id, "SimulationDataPoint Script failed")
  communicate_debug_log(id, e.message)
  communicate_debug_log(id, e.backtrace)

  # need to tell mongo this failed
  communicateFailure(id)

  # raise last exception
  # raise  #NL: Don't raise an exception because this will be sent to R and it will not know how to process it.
end

communicate_debug_log(id, "Complete")

# DLM: this is where we put the objective functions.  NL: Note that we must return out of this nicely no matter what.
puts "0"
