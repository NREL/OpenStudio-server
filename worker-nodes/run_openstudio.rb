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

  options[:profile_run] = false
  opts.on("-p", "--profile-run", "Profile the Run OpenStudio Call") do |pr|
    options[:profile_run] = pr
  end
end
optparse.parse!

puts "Parsed Input: #{optparse}"

if options[:profile_run]
  require 'ruby-prof'
  RubyProf.start
end

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

require 'analysis_chauffeur'
ros = AnalysisChauffeur.new(options[:uuid])

# let listening processes know that this data point is running
ros.log_message "File #{__FILE__} started executing on #{options[:uuid]}", true

# get the directory as an openstudio path
directory = OpenStudio::Path.new(options[:directory])
project_path = directory.parent_path.parent_path
# on linux, if directory ends in /, need to call parent_path
if directory.stem.to_s == String.new
  directory = directory.parent_path
end
logLevel = options[:logLevel].to_i

ros.log_message "Project directory is  #{project_path.to_s}", true
ros.log_message "Run directory is #{directory.to_s}", true
objective_function_result = nil

begin
  # set up log file
  logSink = OpenStudio::FileLogSink.new(directory / OpenStudio::Path.new("openstudio.log"))
  logSink.setLogLevel(logLevel)
  OpenStudio::Logger::instance.standardOutLogger.disable

  ros.log_message "Getting Problem JSON input", true

  # get json from database
  data_point_json, analysis_json = ros.get_problem("json")

  # Get database point by index of manipulation (THIS IS NOT YET KNOWN)

  ros.log_message "Parsing Analysis JSON input", true

  # load problem formulation
  loadResult = OpenStudio::Analysis::loadJSON(analysis_json)
  if loadResult.analysisObject.empty?
    loadResult.errors.each { |error|
      warn error.logMessage
    }
    raise "Unable to load analysis json."
  end

  ros.log_message "Get Analysis From OpenStudio", true
  analysis = loadResult.analysisObject.get.to_Analysis.get

  # fix up paths
  ros.log_message "Fix Paths", true
  analysis.updateInputPathData(loadResult.projectDir, project_path)
  analysis_options = OpenStudio::Analysis::AnalysisSerializationOptions.new(project_path)
  analysis.saveJSON(directory / OpenStudio::Path.new("formulation_final.json"), analysis_options, true)

  ros.log_message "Parsing DataPoint JSON input", true

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

  ros.log_message "Communicating DataPoint", true

  # update datapoint in database -- huh?
  ros.communicate_datapoint(data_point)

  ros.log_message "Creating Run Manager", true

  # create a RunManager
  run_manager_path = directory / OpenStudio::Path.new("run.db")
  run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_path, true, false, false)

  # have problem create the workflow
  ros.log_message "Creating Workflow", true
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
  ros.log_message "Queue RunManager Job", true
  url_search_paths = OpenStudio::URLSearchPathVector.new
  weather_file_path = OpenStudio::Path.new
  if (analysis.weatherFile)
    weather_file_path = analysis.weatherFile.get.path
  end
  job = workflow.create(directory, analysis.seed.path, weather_file_path, url_search_paths)
  OpenStudio::Runmanager::JobFactory::optimizeJobTree(job)
  analysis.setDataPointRunInformation(data_point, job, OpenStudio::PathVector.new);
  run_manager.enqueue(job, false);

  ros.log_message "Waiting for simulation to finish", true

  # Get some introspection on what the current running job is. For now just
  # look at the directories that are being generated
  job_dirs = []
  while run_manager.workPending()
    sleep 1
    OpenStudio::Application::instance().processEvents()

    # check if there are any new folders that were creates
    temp_dirs = Dir[File.join(directory.to_s, "*/")].map { |d| d.split("/").pop }.sort
    if (temp_dirs + job_dirs).uniq != job_dirs
      ros.log_message "#{(temp_dirs - job_dirs).join(",")}", true
      job_dirs = temp_dirs
    end
  end

  ros.log_message "Simulation finished", true

  # use the completed job to populate data_point with results
  ros.log_message "Updating OpenStudio DataPoint object", true
  analysis.problem.updateDataPoint(data_point, job)


  ros.log_message "Communicating Results", true

  # implemented differently for Local vs. Vagrant or AWS
  ros.communicate_results(data_point, directory)

  if options[:profile_run]
    profile_results = RubyProf.stop
    File.open("#{directory.to_s}/profile-graph.html", "w") { |f| RubyProf::GraphHtmlPrinter.new(profile_results).print(f) }
    File.open("#{directory.to_s}/profile-flat.txt", "w") { |f| RubyProf::FlatPrinter.new(profile_results).print(f) }
    File.open("#{directory.to_s}/profile-tree.prof", "w") { |f| RubyProf::CallTreePrinter.new(profile_results).print(f) }
  end

  # now set the objective function value or values
  objective_function_result = 0
rescue Exception => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace}"
  ros.log_message log_message, true

  # need to tell the system that this failed
  ros.communicate_failure()
ensure
  ros.log_message "#{__FILE__} Completed", true


  # DLM: this is where we put the objective functions.  NL: Note that we must return out of this file nicely no matter what.
  objective_function_result ||= "NA"

  puts objective_function_result
end

