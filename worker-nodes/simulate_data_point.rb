# Command line based interface to execute the Workflow manager.

require 'bundler'
begin
  Bundler.setup
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'optparse'
require 'fileutils'
require 'logger'
require 'openstudio-workflow'

puts "Parsing Input: #{ARGV}"

# parse arguments with optparse
options = {}
optparse = OptionParser.new do |opts|
  opts.on('-a', '--analysis_id UUID', String, 'UUID of the analysis.') do |analysis_id|
    options[:analysis_id] = analysis_id
  end

  options[:uuid] = 'NA'
  opts.on('-u', '--uuid UUID', String, 'UUID of the data point to run with no braces.') do |s|
    options[:uuid] = s
  end

  options[:run_shm] = false
  opts.on('--run-shm', 'Run on SHM Volume') do
    options[:run_shm] = true
  end

  options[:run_shm_dir] = '/run/shm'
  opts.on('-D', '--shm-dir SHM_PATH', String, 'Path of the SHM Volume on the System.') do |s|
    options[:run_shm_dir] = s
  end

  options[:run_data_point_filename] = 'run_openstudio.rb'
  opts.on('-x', '--execute-file NAME', String, 'Name of the file to copy and execute') do |s|
    options[:run_data_point_filename] = s
  end

end
optparse.parse!

puts "Parsed Input: #{optparse}"

puts 'Checking Arguments'
unless options[:uuid]
  # required argument is missing
  puts optparse
  exit
end

# Set the result of the project for R to know that this finished
result = nil

begin
  directory = nil
  fail "Data Point is NA... skipping" if options[:uuid] == 'NA'
  analysis_dir = "/mnt/openstudio/analysis_#{options[:analysis_id]}"
  store_directory = "/mnt/openstudio/analysis_#{options[:analysis_id]}/data_point_#{options[:uuid]}"
  FileUtils.mkdir_p(store_directory)

  # use /run/shm on AWS (if possible)
  if options[:run_shm] && Dir.exist?(options[:run_shm_dir])
    analysis_dir = "#{options[:run_shm_dir]}/openstudio/analysis_#{options[:analysis_id]}"
    directory = "#{options[:run_shm_dir]}/openstudio/analysis_#{options[:analysis_id]}/data_point_#{options[:uuid]}"
  else
    directory = store_directory
  end

  # Logger for the simulate datapoint
  logger = Logger.new("#{directory}/#{options[:uuid]}.log")

  logger.info "Analysis Root Directory is #{analysis_dir}"
  logger.info "Simulation Run Directory is #{directory}"
  logger.info "Simulation Storage Directory is #{store_directory}"
  logger.info "Run datapoint type/file is #{options[:run_data_point_filename]}"

  # TODO: program the various paths based on the run_data_point_filename
  # TODO: rename run_data_point_filename to run_workflow_method

  workflow_options = nil
  if options[:run_data_point_filename] == 'workflow_monthly' ||
      options[:run_data_point_filename] == 'run_openstudio_workflow_monthly.rb'
    workflow_options = {
      datapoint_id: options[:uuid],
      analysis_root_path: analysis_dir,
      use_monthly_reports: true,
      adapter_options: {
        mongoid_path: '/mnt/openstudio/rails-models'
      }
    }

  elsif options[:run_data_point_filename] == 'workflow' ||
      options[:run_data_point_filename] == 'run_openstudio_workflow.rb'
    workflow_options = {
      datapoint_id: options[:uuid],
      analysis_root_path: analysis_dir,
      use_monthly_reports: false,
      adapter_options: {
        mongoid_path: '/mnt/openstudio/rails-models'
      }
    }
  elsif options[:run_data_point_filename] == 'custom_xml' ||
      options[:run_data_point_filename] == 'run_openstudio_xml.rb'

    # Set up the custom workflow states and transitions
    transitions = OpenStudio::Workflow::Run.default_transition
    transitions[1][:to] = :xml
    transitions.insert(2, from: :xml, to: :openstudio)
    states = OpenStudio::Workflow::Run.default_states
    states.insert(2, :state => :xml, :options => {:after_enter => :run_xml})

    workflow_options = {
      transitions: transitions,
      states: states,
      analysis_root_path: analysis_dir,
      datapoint_id: options[:uuid],
      use_monthly_reports: true,
      xml_library_file: "#{analysis_dir}/lib/openstudio_xml/main.rb",
      adapter_options: {
        mongoid_path: '/mnt/openstudio/rails-models'
      }
    }
  elsif options[:run_data_point_filename] == 'legacy_workflow' ||
      options[:run_data_point_filename] == 'run_openstudio.rb'
    workflow_options = {
      datapoint_id: options[:uuid],
      analysis_root_path: analysis_dir,
      use_monthly_reports: false,
      adapter_options: {
        mongoid_path: '/mnt/openstudio/rails-models'
      }
    }
  end

  logger.info 'Creating Workflow Manager instance'
  k = OpenStudio::Workflow.load 'Mongo', directory, workflow_options
  logger.info "Running workflow with #{options}"
  k.run

  # TODO: get the last results out --- result = result.split("\n").last if result

  # copy the files that are needed over to the run directory
  if options[:run_shm]
    # only grab the zip/log files and put back in store_directory
    zip_file = "#{directory}/data_point_#{options[:uuid]}.zip"
    dest_zip_file = "#{store_directory}/data_point_#{options[:uuid]}.zip"
    puts "Trying to move zip file from #{zip_file} to #{dest_zip_file}"
    if File.exist?(zip_file)
      FileUtils.rm_f(dest_zip_file) if File.exist?(dest_zip_file)
      puts 'Moving zip file'
      FileUtils.move(zip_file, dest_zip_file)
    end

    log_file = "#{directory}/#{options[:uuid]}.log"
    dest_log_file = File.expand_path("#{store_directory}/../#{options[:uuid]}-run_os.log")
    if File.exist?(log_file)
      FileUtils.rm_f(dest_log_file) if File.exist?(dest_log_file)
      FileUtils.move(log_file, dest_log_file)
    end

    puts "Removing directory from shm #{directory}"
    FileUtils.rm_rf(directory) if Dir.exist?(directory)
  end

  # check if the simulation failed after moving the files back to the right place
  if result == 'NA'
    fail 'Simulation result was invalid'
  end
rescue => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  puts log_message
  logger.info log_message if logger
ensure
  logger.close if logger
  # always print the objective function result or NA
  puts result
end
