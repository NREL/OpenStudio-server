require 'optparse'
require 'fileutils'

puts "Parsing Input: #{ARGV}"

# parse arguments with optparse
options = Hash.new
optparse = OptionParser.new do |opts|
  opts.on('-a', '--analysis_id UUID', String, "UUID of the analysis.") do |analysis_id|
    options[:analysis_id] = analysis_id
  end

  opts.on('-u', '--uuid UUID', String, "UUID of the data point to run with no braces.") do |s|
    options[:uuid] = s
  end

  # TODO delete AWS argument.  Not needed at the moment.
  options[:runType] = "AWS"
  opts.on('-r', '--runType RUNTYPE', String, "String that indicates where simulate data point is being run (Local|Vagrant|AWS).") do |s|
    options[:runType] = s
  end

  options[:logLevel] = -1
  opts.on('-l', '--logLevel LOGLEVEL', Integer, "Level of detail for project.log file. Trace = -3, Debug = -2, Info = -1, Warn = 0, Error = 1, Fatal = 2.") do |i|
    options[:logLevel] = i
  end

  options[:run_shm] = false
  opts.on('-s', '--run-shm', "Run on SHM Volume") do
    options[:run_shm] = true
  end

  options[:debug] = false
  opts.on('--debug', "Set the debug flag") do
    options[:debug] = true
  end

  options[:run_shm_dir] = "/run/shm"
  opts.on('-D', '--shm-dir SHM_PATH', String, "Path of the SHM Volume on the System.") do |s|
    options[:run_shm_dir] = s
  end

  options[:run_data_point_filename] = "run_openstudio.rb"
  opts.on('-x' '--execute-file NAME', String, "Name of the file to copy and execute") do |s|
    options[:run_data_point_filename] = s
  end
  
  options[:run_manager_type] = "openstudio_core"
  opts.on('-t' '--run-manager NAME', String, "Type of RunManager that is used [openstudio_core or workflow]") do |s|
    options[:run_manager_type] = s
  end
end
optparse.parse!

puts "Parsed Input: #{optparse}"

puts "Checking Arguments"
if not options[:uuid]
  # required argument is missing
  puts optparse
  exit
end

libdir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)
require 'analysis_chauffeur'

ros = AnalysisChauffeur.new(options[:uuid])     
ros.reload

# Set the result of the project for R to know that this finished
result = nil

# load in the workflow helpers module
require_relative 'workflow_helpers'

begin
  ros.communicate_started() # this initializes everything as well
  ros.log_message "Running Simulate Data Point: #{__FILE__}", true

  directory = nil
  analysis_dir = "/mnt/openstudio"
  store_directory = "/mnt/openstudio/analysis_#{options[:analysis_id]}/data_point_#{options[:uuid]}"
  FileUtils.mkdir_p(store_directory)

  # use /run/shm on AWS (if possible)
  if options[:run_shm] && Dir.exists?(options[:run_shm_dir])
    analysis_dir = "#{options[:run_shm_dir]}/openstudio"
    directory = "#{options[:run_shm_dir]}/openstudio/analysis_#{options[:analysis_id]}/data_point_#{options[:uuid]}"
  else
    directory = store_directory
  end

  ros.log_message "Analysis Directory is #{analysis_dir}", true
  ros.log_message "Simulation Run Directory is #{directory}", true
  ros.log_message "Simulation Storage Directory is #{store_directory}", true

  # copy the files that are needed over to the run directory
  WorkflowHelpers.prepare_run_directory("/mnt/openstudio", directory, options)

  # construct the command to be called
  command = "ruby -I/mnt/openstudio #{directory}/#{options[:run_data_point_filename]} -u #{options[:uuid]} -d #{directory}"
  ros.log_message "Calling #{command}", true
  result = `#{command}`

  result = result.split("\n").last if result

  # Save the results file
  stdout_file_name = "#{directory}/#{options[:uuid]}.log"
  FileUtils.rm(stdout_file_name) if File.exists?(stdout_file_name)
  File.open(stdout_file_name, 'w') {|f| f << result}

  # since the run_openstudio method also loads the data point, this is to reload the data point to get the data refreshed
  ros.reload
  ros.log_message "command result is: #{result}"

  # put the data back into the "long term store"
  if options[:run_shm]
    # only grab the zip/log files and put back in store_directory
    zip_file = "#{directory}/data_point_#{options[:uuid]}.zip"
    dest_zip_file = "#{store_directory}/data_point_#{options[:uuid]}.zip"
    puts "Trying to move zip file from #{zip_file} to #{dest_zip_file}"
    if File.exists?(zip_file)
      FileUtils.rm_f(dest_zip_file) if File.exists?(dest_zip_file)
      puts "Moving zip file"
      FileUtils.move(zip_file, dest_zip_file)
    end

    log_file = "#{directory}/#{options[:uuid]}.log"
    dest_log_file = File.expand_path("#{store_directory}/../#{options[:uuid]}-run_os.log")
    if File.exists?(log_file)
      FileUtils.rm_f(dest_log_file) if File.exists?(dest_log_file)
      FileUtils.move(log_file, dest_log_file)
    end

    puts "Removing directory from SHM #{directory}"
    FileUtils.rm_rf(directory) if Dir.exist?(directory)
  end

  # check if the simulation failed after moving the files back to the right place
  if result == "NA"
    raise "Simulation result was invalid"
  end

  ros.communicate_complete()
rescue Exception => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  ros.log_message log_message, true

  # need to tell mongo this failed
  ros.communicate_failure()
ensure
  
  # always print the objective function result or NA
  puts result
end
