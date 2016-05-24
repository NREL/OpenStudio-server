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
require 'securerandom'

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
  dp_uuid = SecureRandom.uuid
  analysis_root_path = "analysis_#{options[:analysis_id]}"
  run_directory = "analysis_#{options[:analysis_id]}/data_point_#{dp_uuid}"
  # Logger for the simulate datapoint
  logger = Logger.new("#{analysis_root_path}/create_data_point_#{dp_uuid}.log")
  logger.info "Parsed Input: #{options}"
  logger.info "Analysis id is #{options[:analysis_id]}"

  workflow_options = {
    datapoint_id: dp_uuid,
    analysis_root_path: analysis_root_path,
    adapter_options: {
      mongoid_path: File.expand_path('rails-models'),
      rails_env: ENV['RAILS_ENV'] || 'development'
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
            sample[uuid] = value.casecmp('true').zero? ? true : false
          else
            raise "Unknown DataType for variable #{var_db.name} of #{var_db.value_type}"
        end
      else
        raise 'Could not find variable in database'
      end
    end
  else
    raise 'no variables in array'
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
  # Must print out a dp uuid or and NA
  #   NA's are caught by the R algorithm as an error
  final_result = 'NA'
  if dp && !errored
    final_result = dp.uuid
  end
  puts final_result
end
