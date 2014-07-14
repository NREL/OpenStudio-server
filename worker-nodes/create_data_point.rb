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

errored = false

begin
  dp_uuid = UUID.new.generate
  analysis_root_path = "/mnt/openstudio/analysis_#{options[:analysis_id]}"
  run_directory = "/mnt/openstudio/analysis_#{options[:analysis_id]}/data_point_#{dp_uuid}"
  # Logger for the simulate datapoint
  logger = Logger.new("#{analysis_root_path}/create_data_point_#{dp_uuid}.log")
  logger.info "Parsed Input: #{options}"
  logger.info "Analysis id is #{options[:analysis_id]}"

  workflow_options = {
    datapoint_id: dp_uuid,
    analysis_root_path: analysis_root_path,
    adapter_options: {
      mongoid_path: '/mnt/openstudio/rails-models'
    }
  }

  logger.info 'Creating Mongo connector'
  k = OpenStudio::Workflow.load 'Mongo', run_directory, workflow_options
  logger.info 'Created Mongo connector'

  k.logger.info 'Creating new datapoint'
  logger.info 'Creating new datapoint'
  dp = DataPoint.find_or_create_by(uuid: dp_uuid)
  dp.name = "Autocreated on worker: #{dp_uuid}"
  dp.analysis_id = options[:analysis_id]

  logger.info 'Saving new datapoint'
  unless dp.save!
    logger.error "Could not save the datapoint into the database with error #{dp.errors.full_messages}"
  end
  logger.info 'Saved new datapoint'

  sample = {} # {variable_uuid_1: value1, variable_uuid_2: value2}

  if options[:variables]
    k.logger.info "Applying variables: #{options[:variables]}"
    options[:variables].each_with_index do |value, index|
      r_index_value = index + 1
      k.logger.info "Adding new variable value with r_index #{r_index_value} of value #{value}"

      # TODO: check for nil variables
      var_db = Variable.where(analysis_id: dp.analysis_id, r_index: r_index_value).first
      if var_db
        uuid = var_db.uuid

        case var_db.value_type.downcase
          when 'double'
            sample[uuid] = value.to_f
          when 'string'
            sample[uuid] = value.to_s
          when 'integer', 'int'
            sample[uuid] = value.to_i
          when 'bool', 'boolean'
            sample[uuid] = value.downcase == 'true' ? true : false
          else
            fail "Unknown DataType for variable #{var_db.name} of #{var_db.value_type}"
        end
      else
        fail 'Could not find variable in database'
      end
    end
  else
    fail 'no variables in array'
  end

  k.logger.info "new variable values are #{sample}" if k
  dp.set_variable_values = sample
  dp.save!

  k.logger.info 'Finished creating new datapoint'
rescue => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  k.logger.info log_message if k

  errored = true
ensure
  # Must print out a dp uuid of some sort, default is NA
  puts (dp && !errored) ? dp.uuid : 'NA'
end
