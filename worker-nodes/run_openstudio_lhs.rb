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

ros.log_message "Run directory is #{directory.to_s}", true
objective_function_result = nil

begin

  ros.log_message "Getting Problem JSON input", true

  # get json from database
  data_point_json, analysis_json = ros.get_problem_json()
  ros.log_message data_point_json
  ros.log_message analysis_json


  ros.log_message "Parsing Analysis JSON input", true

  # by hand for now, go and get the information about the measures

  ros.log_message "Get Analysis From OpenStudio", true

  ros.log_message "Fix Paths", true

  ros.log_message "Parsing DataPoint JSON input", true

  ros.log_message "Communicating DataPoint", true

  #ros.communicate_datapoint(data_point)

  ros.log_message "Creating Run Manager", true

  ros.log_message "Creating Workflow", true

  ros.log_message "Queue RunManager Job", true

  ros.log_message "Waiting for simulation to finish", true

  ros.log_message "Simulation finished", true

  # use the completed job to populate data_point with results
  ros.log_message "Updating OpenStudio DataPoint object", true

  ros.log_message "Communicating Results", true

  # implemented differently for Local vs. Vagrant or AWS
  #ros.communicate_results(data_point, directory)

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

