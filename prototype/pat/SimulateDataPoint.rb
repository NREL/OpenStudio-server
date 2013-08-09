
require 'openstudio'
require 'optparse'

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
logLevel = options[:logLevel].to_i

# verify the existence of required files
data_point_json_path = directory / OpenStudio::Path.new("data_point_in.json")
formulation_json_path = directory.parent_path / OpenStudio::Path.new("formulation.json")
tools_json_path = directory.parent_path / OpenStudio::Path.new("tools.json")
raise "Required file '" + data_point_json_path.to_s + "' does not exist." if not File.exist?(data_point_json_path.to_s)
raise "Required file '" + formulation_json_path.to_s + "' does not exist." if not File.exist?(formulation_json_path.to_s)
raise "Required file '" + tools_json_path.to_s + "' does not exist." if not File.exist?(tools_json_path.to_s)

# set up log file
logSink = OpenStudio::FileLogSink.new(directory / OpenStudio::Path.new("openstudio.log"))
logSink.setLogLevel(logLevel)
OpenStudio::Logger::instance.standardOutLogger.disable

# load problem formulation
analysis = OpenStudio::Analysis::loadJSON(formulation_json_path)
raise "Unable to load json file from '" + formulation_json_path.to_s + "." if analysis.empty?
analysis = analysis.get.to_Analysis.get

# ETH@20130808 Replace the following fix up code with a single method call to analysis
# to swap out project directories (similar to what osp does on open)

# project paths
original_project_path = analysis.seed.path.parent_path.parent_path
new_project_path = directory.parent_path
puts "Fixing up file paths originally at '" + original_project_path.to_s + 
     "' to now be at '" + new_project_path.to_s + "'."

# fix up seed model path
new_seed_path = new_project_path / OpenStudio::Path.new("seed/seed.osm")
ok = analysis.setSeed(OpenStudio::FileReference.new(new_seed_path))
raise "Unable to fix up seed model path to '" + new_seed_path.to_s + "'." if not ok

# fix up weather file path
weather_file_path = OpenStudio::Path.new
if not analysis.weatherFile.empty?
  weather_file_path = analysis.weatherFile.get.path
  weather_file_path = OpenStudio::relocatePath(weather_file_path,
                                               original_project_path,
                                               new_project_path)
end

# fix up measure paths
scripts_dir = new_project_path / OpenStudio::Path.new("scripts")
Dir.foreach(scripts_dir.to_s) do |script_folder|
  next if script_folder == '.' or script_folder == '..'
  bclMeasure = OpenStudio::BCLMeasure.new( scripts_dir / OpenStudio::Path.new(script_folder))
  analysis.problem.updateMeasure(bclMeasure,OpenStudio::Ruleset::OSArgumentVector.new,true)
end
debug_formulation_json_path = directory / OpenStudio::Path.new("fixed_up_formulation.json")
analysis.saveJSON(debug_formulation_json_path,"ProblemFormulation".to_AnalysisSerializationScope)

# load data point to run
data_point = OpenStudio::Analysis::loadJSON(data_point_json_path)
raise "Unable to laod json file from '" + data_point_json_path.to_s + "." if data_point.empty?
data_point = data_point.get.to_DataPoint.get
raise "DataPoint was not created by Problem." if data_point.problemUUID != analysis.problem.uuid

# create a RunManager
run_manager_path = directory / OpenStudio::Path.new("run.db")
run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_path,true,false,false)

# have problem create the workflow
workflow = analysis.problem.createWorkflow(data_point,OpenStudio::Path.new($OpenStudio_Dir));
params = OpenStudio::Runmanager::JobParams.new;
params.append("cleanoutfiles","standard"); # ETH@20130808 This needs to come in as an option.
workflow.add(params);
file = File.open(tools_json_path.to_s,'rb')
tools = OpenStudio::Runmanager::WorkItem::fromJSON(file.read).tools
workflow.add(tools)

# queue the RunManager job
url_search_paths = OpenStudio::URLSearchPathVector.new
job = workflow.create(directory,new_seed_path,weather_file_path,url_search_paths)
OpenStudio::Runmanager::JobFactory::optimizeJobTree(job)
analysis.setDataPointRunInformation(data_point, job, OpenStudio::PathVector.new);
run_manager.enqueue(job,false);

# wait for the job to finish
run_manager.waitForFinished

# use the completed job to populate data_point with results
analysis.problem.updateDataPoint(data_point,job)

# for now, print the final data point json
data_point_json_path = directory / OpenStudio::Path.new("data_point_out.json")
data_point.saveJSON(data_point_json_path,true)
