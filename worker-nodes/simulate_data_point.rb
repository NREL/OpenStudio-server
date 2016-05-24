#*******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#*******************************************************************************

# Command line based interface to execute the Workflow manager.

# ruby worker_init_final.rb -h localhost:3000 -a 330f3f4a-dbc0-469f-b888-a15a85ddd5b4 -s initialize
# ruby simulate_data_point.rb -h localhost:3000 -a 330f3f4a-dbc0-469f-b888-a15a85ddd5b4 -u 1364e270-2841-407d-a495-cf127fa7d1b8

require 'bundler'
begin
  Bundler.setup
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'openstudio-workflow'
require 'optparse'
require 'fileutils'
require 'logger'
require 'rest-client'

puts "Parsing Input: #{ARGV}"

# parse arguments with optparse
options = {}
optparse = OptionParser.new do |opts|
  opts.on('-h', '--host host:port', String, 'Server host and port (e.g. localhost:3000)') do |host|
    options[:host] = host
  end

  opts.on('-a', '--analysis_id UUID', String, 'UUID of the analysis.') do |analysis_id|
    options[:analysis_id] = analysis_id
  end

  options[:uuid] = 'NA'
  opts.on('-u', '--uuid UUID', String, 'UUID of the data point to run with no braces.') do |s|
    options[:uuid] = s
  end

  options[:run_workflow_method] = 'workflow'
  opts.on('-x', '--execute-file NAME', String, 'Type of the workflow the run will execute') do |s|
    options[:run_workflow_method] = s
  end
end
optparse.parse!

puts 'Checking Arguments'
unless options[:host]
  puts 'Must provide host'
  puts optparse
  exit
end

unless options[:uuid]
  # required argument is missing
  puts 'Must provide datapoint uuid'
  puts optparse
  exit
end

# Set the result of the project for R to know that this finished
result = nil

begin
  raise 'Data Point is NA... skipping' if options[:uuid] == 'NA'
  analysis_dir = File.expand_path("analysis_#{options[:analysis_id]}")
  directory = File.expand_path("analysis_#{options[:analysis_id]}/data_point_#{options[:uuid]}")
  FileUtils.mkdir_p(directory)

  # Logger for the simulate datapoint
  logger = Logger.new("#{directory}/#{options[:uuid]}.log")

  logger.info "Server host is #{options[:host]}"
  logger.info "Analysis root directory is #{analysis_dir}"
  logger.info "Simulation run directory is #{directory}"
  logger.info "Run data point type/file is #{options[:run_workflow_method]}"

  # delete any existing data files from the server in case this is a 'rerun'
  RestClient.delete "http://#{options[:host]}/data_points/#{options[:uuid]}/result_files"

  # Set the default workflow options
  workflow_options = {
    datapoint_id: options[:uuid],
    analysis_root_path: analysis_dir,
    adapter_options: {
      mongoid_path: File.expand_path('rails-models'),
      rails_env: ENV['RAILS_ENV'] || 'development'
    }
  }
  if options[:run_workflow_method] == 'custom_xml' ||
     options[:run_workflow_method] == 'run_openstudio_xml.rb'

    # Set up the custom workflow states and transitions
    transitions = OpenStudio::Workflow::Run.default_transition
    transitions[1][:to] = :xml
    transitions.insert(2, from: :xml, to: :openstudio)
    states = OpenStudio::Workflow::Run.default_states
    states.insert(2, state: :xml, options: { after_enter: :run_xml })

    workflow_options = {
      transitions: transitions,
      states: states,
      analysis_root_path: analysis_dir,
      datapoint_id: options[:uuid],
      xml_library_file: "#{analysis_dir}/lib/openstudio_xml/main.rb",
      adapter_options: {
        mongoid_path: File.expand_path('rails-models'),
        rails_env: ENV['RAILS_ENV'] || 'development'
      }
    }
  elsif options[:run_workflow_method] == 'pat_workflow' ||
        options[:run_workflow_method] == 'run_openstudio.rb'
    workflow_options = {
      is_pat: true,
      datapoint_id: options[:uuid],
      analysis_root_path: analysis_dir,
      adapter_options: {
        mongoid_path: File.expand_path('rails-models'),
        rails_env: ENV['RAILS_ENV'] || 'development'
      }
    }
  end

  logger.info 'Creating Workflow Manager instance'
  logger.info "Directory is #{directory}"
  logger.info "Workflow options are #{workflow_options}"
  k = OpenStudio::Workflow.load 'Mongo', directory, workflow_options
  logger.info "Running workflow with #{options}"
  k.run
  logger.info "Final run state is #{k.final_state}"

  # TODO: get the last results out --- result = result.split("\n").last if result
  # check if the simulation failed after moving the files back to the right place
  if result == 'NA'
    logger.info 'Simulation result was invalid'
    raise 'Simulation result was invalid'
  end

  # Post the data back to the server
  # TODO: check for timeouts and retry
  Dir["#{directory}/reports/*.{html,json,csv}"].each do |report|
    RestClient.post(
      "http://#{options[:host]}/data_points/#{options[:uuid]}/upload_file",
      file: {
        display_name: File.basename(report, '.*'),
        type: 'Report',
        attachment: File.new(report, 'rb')
      }
    )
  end

  # Post the results too
  # TODO: Do not save the _reports file anymore in the workflow gem
  results_zip = "#{directory}/data_point_#{options[:uuid]}.zip"
  if File.exist? results_zip
    RestClient.post(
      "http://#{options[:host]}/data_points/#{options[:uuid]}/upload_file",
      file: {
        display_name: 'Zip File',
        type: 'Data Point',
        attachment: File.new(results_zip, 'rb')
      }
    )
  end
rescue => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  puts log_message
  logger.info log_message if logger
ensure
  logger.info "Finished #{__FILE__}" if logger
  logger.close if logger

  # always print out the state at the end
  puts result # as a string? (for R to parse correctly?)
end
