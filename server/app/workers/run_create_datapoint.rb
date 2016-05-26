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

class RunCreateDatapoint
  def initialize(analysis_id, variables, options = {})
    defaults = { run_workflow_method: 'workflow'}.with_indifferent_access
    @options = defaults.deep_merge(options)

    @analysis = Analysis.find(analysis_id)
    @variables = variables

    # Create a new datapoint UUID
    @dp_uuid = SecureRandom.uuid
  end

  def perform
    if @analysis.nil?
      status_message = 'Could not find analysis in which to create datapoint'
      fail status_message
    end

    FileUtils.mkdir_p analysis_dir unless Dir.exist? analysis_dir
    FileUtils.mkdir_p simulation_dir unless Dir.exist? simulation_dir

    # Logger for the simulate datapoint
    sim_logger = Logger.new("#{analysis_dir}/create_data_point_#{@dp_uuid}.log")
    sim_logger.info "Analysis ID: #{@analysis.id}"
    sim_logger.info "Variables: #{@variables}"
    sim_logger.info "New Datapoint ID: #{@dp_uuid}"

    # Create the analysis directory
    sim_logger.info 'Creating new datapoint'
    dp = DataPoint.find_or_create_by(uuid: @dp_uuid)
    dp.name = "Autocreated on worker: #{@dp_uuid}"
    dp.analysis_id = @analysis.id

    sim_logger.info 'Saving new datapoint'
    unless dp.save!
      sim_logger.error "Could not save the datapoint into the database with error #{dp.errors.full_messages}"
    end
    sim_logger.info 'Saved new datapoint'

    sample = {} # {variable_uuid_1: value1, variable_uuid_2: value2}

    if @variables
      sim_logger.info "Applying variables: #{@variables}"
      @variables.each_with_index do |value, index|
        r_index_value = index + 1
        sim_logger.info "Adding new variable value with r_index #{r_index_value} of value #{value}"

        var_db = Variable.where(analysis_id: @analysis.id, r_index: r_index_value).first
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

    dp.set_variable_values = sample
    dp.save!

    sim_logger.info 'Finished creating new datapoint'
  rescue => e
    log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
    puts log_message
    sim_logger.info log_message if sim_logger
  ensure
    sim_logger.info "Finished #{__FILE__}" if sim_logger
    sim_logger.close if sim_logger

    return @dp_uuid
  end

  private

  def analysis_dir
    "#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}"
  end

  def simulation_dir
    "#{analysis_dir}/data_point_#{@dp_uuid}"
  end

  # Return the logger for delayed jobs which is typically rails_root/log/delayed_job.log
  def logger
    Delayed::Worker.logger
  end
end
