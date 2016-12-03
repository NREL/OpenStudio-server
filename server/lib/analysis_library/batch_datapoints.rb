# *******************************************************************************
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
# *******************************************************************************

class AnalysisLibrary::BatchDatapoints < AnalysisLibrary::Base
  def initialize(analysis_id, analysis_job_id, options = {})
    # Setup the defaults for the Analysis.  Items in the root are typically used to control the running of
    #   the script below and are not necessarily persisted to the database.
    #   Options under problem will be merged together and persisted into the database.  The order of
    #   preference is objects in the database, objects passed via options, then the defaults below.
    #   Parameters posted in the API become the options hash that is passed into this initializer.
    defaults = {
      skip_init: false,
      run_data_point_filename: 'run_openstudio_workflow.rb',
      problem: {}
    }.with_indifferent_access # make sure to set this because the params object from rails is indifferent
    @options = defaults.deep_merge(options)

    @analysis_id = analysis_id
    @analysis_job_id = analysis_job_id
  end

  # Perform is the main method that is run in the background.  At the moment if this method crashes
  # it will be logged as a failed delayed_job and will fail after max_attempts.
  def perform
    @analysis = Analysis.find(@analysis_id)

    # get the analysis and report that it is running
    @analysis_job = AnalysisLibrary::Core.initialize_analysis_job(@analysis, @analysis_job_id, @options)

    # reload the object (which is required) because the sub-documents (jobs) may have changed
    @analysis.reload

    # Create an instance for R
    begin
      logger.info "Initializing analysis for #{@analysis.name} with UUID of #{@analysis.uuid}"
      logger.info "Setting up R for #{self.class.name}"

      selected_variables = Variable.variables(@analysis.id)
      logger.info "Found #{selected_variables.count} non-default variables in the batch datapoint set."

      # generate the probabilities for all variables as column vectors
      samples = nil

      logger.info 'Starting batch datapoint extraction.'

      # Iterate through each variable based on the method and add to the samples array in the form of
      # [{a: 1, b: true, c: 's'}, {a: 2, b: false, c: 'n'}]
      values_length = []
      values_set = {}

      selected_variables.each do |var|
        if var.map_discrete_hash_to_array.nil? || var.discrete_values_and_weights.empty?
          raise "no hash values and weight passed in variable #{var.name}"
        end
        values, weights = var.map_discrete_hash_to_array
        raise "'nil' value(s) found in variable #{var.id}. nil values not yet supported." if values.count(&:nil?).nonzero?
        values_length = values_length << values.length
        values_set[var.id.to_s.to_sym] = values
      end

      raise 'Length of discrete_values passed in variables was not equal across variables.' if values_length.uniq.length != 1

      # Create Datapoint Samples
      logger.info 'Creating datapoint samples'
      samples = []
      for i in 0..(values_length[0] - 1)
        instance = {}
        selected_variables.each do |var|
          instance[var.id.to_s.to_sym] = values_set[var.id.to_s.to_sym][i]
        end
        samples << instance
      end

      # Add the datapoints to the database
      logger.info 'Adding the datapoints to the database'
      isample = 0
      dp_da_options = @analysis.problem['design_alternatives'] ? true : false
      samples.each do |sample| # do this in parallel
        dp_name = "Autogenerated #{isample}"
        dp_description = "Autogenerated #{isample}"
        if dp_da_options
          dp_seed, dp_da_descriptions = false
          instance_da_opts = @analysis.problem['design_alternatives'][isample]
          dp_name = instance_da_opts['name'] if instance_da_opts['name']
          dp_description = instance_da_opts['description'] if instance_da_opts['description']
          dp_seed = File.basename instance_da_opts['seed']['path'] if instance_da_opts['seed']
          if instance_da_opts['options']
            dp_da_descriptions = []
            @analysis.problem['workflow'].each do |step_def|
              wf_da_step = instance_da_opts['options'].select {|h| h['workflow_index'].to_i == step_def['workflow_index'].to_i}
              if wf_da_step.length != 1
                fail "Invalid OSA; multiple workflow_index of #{step_def['workflow_index']} found in the design_alternative options"
              else
                wf_da_step = wf_da_step[0]
              end
              dp_da_descriptions << {name: wf_da_step['name'], description: wf_da_step['description']}
            end
          end
          if dp_seed && dp_da_descriptions
            dp = @analysis.data_points.new(name: dp_name, description: dp_description,
                                           da_descriptions: dp_da_descriptions, dp_seed: dp_seed)
          elsif dp_seed
            dp = @analysis.data_points.new(name: dp_name, description: dp_description, dp_seed: dp_seed)
          elsif dp_da_descriptions
            dp = @analysis.data_points.new(name: dp_name, description: dp_description,
                                           da_descriptions: dp_da_descriptions)
          else
            dp = @analysis.data_points.new(name: dp_name, description: dp_description)
          end
        else
          dp = @analysis.data_points.new(name: dp_name, description: dp_description)
        end
        dp.set_variable_values = sample
        dp.save!
        isample += 1
        logger.info("Generated datapoint #{dp.name} for analysis #{@analysis.name}")
      end

    ensure

      # Only set this data if the analysis was NOT called from another analysis
      unless @options[:skip_init]
        @analysis_job.end_time = Time.now
        @analysis_job.status = 'completed'
        @analysis_job.save!
        @analysis.reload
      end
      @analysis.save!

      logger.info "Finished running analysis '#{self.class.name}'"
    end
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    1
  end
end
