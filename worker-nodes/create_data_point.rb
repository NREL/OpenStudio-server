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
require 'uuid'

puts "Parsing Input: #{ARGV}"

# parse arguments with optparse
options = {}
optparse = OptionParser.new do |opts|
  opts.on('-a', '--analysis_id UUID', String, 'UUID of the analysis.') do |analysis_id|
    options[:analysis_id] = analysis_id
  end

  options[:variables] = []
  opts.on('-v', '--variables 1,2,3', Array, 'Array of variable values') do |a|
    options[:variables] = a
  end
end
optparse.parse!

puts "Parsed Input: #{optparse}"
errored = false
puts "Options are: #{options}"

begin
  dp_uuid = UUID.new.generate
  analysis_dir = "/mnt/openstudio/analysis_#{options[:analysis_id]}"

  workflow_options = {
      datapoint_id: dp_uuid,
      analysis_root_path: analysis_dir,
      adapter_options: {
          mongoid_path: '/mnt/openstudio/rails-models'
      }
  }
  k = OpenStudio::Workflow.load 'Mongo', analysis_dir, workflow_options
  k.logger.info "Creating new datapoint on worker"

  dp = DataPoint.find_or_create_by(uuid: dp_uuid)
  dp.name = "Autocreated on worker: #{dp_uuid}"
  dp.analysis_id = options[:analysis_id]
  dp.save!

  sample = {} # {variable_uuid_1: value1, variable_uuid_2: value2}

  if options[:variables]
    options[:variables].each_with_index do |value, index|
      r_index_value = index + 1
      k.logger.info "adding new variable value with r_index #{r_index_value} of value #{value}"

      # todo check for nil variables
      uuid = Variable.where(r_index: r_index_value).first.uuid

      # need to check type of value and convert here
      sample[uuid] = value.to_f
    end
  else
    fail 'no variables in array'
  end

  k.logger.info "new variable values are #{sample}" if k
  dp.set_variable_values = sample
  dp.save!

rescue Exception => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  k.logger.info log_message if k

  errored = true
ensure
  # Must print out a dp uuid of some sort, default is NA
  puts dp && !errored ? dp.uuid : 'NA'
end
