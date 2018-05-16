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

class AnalysisLibrary::BaselinePerturbation < AnalysisLibrary::Base
  def initialize(analysis_id, analysis_job_id, options = {})
    # Setup the defaults for the Analysis.  Items in the root are typically used to control the running of
    #   the script below and are not necessarily persisted to the database.
    #   Options under problem will be merged together and persisted into the database.  The order of
    #   preference is objects in the database, objects passed via options, then the defaults below.
    #   Parameters posted in the API become the options hash that is passed into this initializer.
    defaults = ActiveSupport::HashWithIndifferentAccess.new(
        {
            skip_init: false,
            run_data_point_filename: 'run_openstudio_workflow.rb',
            problem: {
                algorithm: {
                    in_measure_combinations: 'false',
                    include_baseline_in_combinations: 'false',
                    seed: nil
                }
            }
        }
    )
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

    # reload the object (which is required) because the subdocuments (jobs) may have changed
    @analysis.reload

    # Create an instance for R
    @r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                 APP_CONFIG['rserve_port'])
    begin
      logger.info "Initializing analysis for #{@analysis.name} with UUID of #{@analysis.uuid}"
      logger.info "Setting up R for #{self.class.name}"
      # TODO: need to move this to the module class
      @r.converse("setwd('#{APP_CONFIG['sim_root_path']}')")

      # make this a core method
      if !@analysis.problem['algorithm']['seed'].nil? && (@analysis.problem['algorithm']['seed'].is_a? Numeric)
        logger.info "Setting R base random seed to #{@analysis.problem['algorithm']['seed']}"
        @r.converse("set.seed(#{@analysis.problem['algorithm']['seed']})")
      end

      # pivot_array = Variable.pivot_array(@analysis.id, @r)
      # Rails.logger.info "pivot_array: #{pivot_array}"

      logger.info Variable.variables(@analysis.id).to_s

      selected_variables = Variable.variables(@analysis.id)
      logger.info "Found #{selected_variables.count} variables to perturb"

      # generate the probabilities for all variables as column vectors
      @r.converse("print('starting single perturbation')")
      samples = nil

      logger.info 'Starting sampling'

      # Iterate through each variable based on the method and add to the samples array in the form of
      # [{a: 1, b: true, c: 's'}, {a: 2, b: false, c: 'n'}]
      samples = []

      selected_variables.each do |var|
        logger.info "name: #{var.measure.name}; id: #{var.measure.id}"
      end

      # Make baseline case
      instance = {}
      selected_variables.each do |variable|
        instance[variable.id.to_s.to_sym] = variable.static_value
      end
      samples << instance

      # Make perturbed cases
      if @analysis.problem['algorithm']['in_measure_combinations'].casecmp('false').zero?
        logger.info 'In False'
        selected_variables.each do |variable|
          if variable.map_discrete_hash_to_array.nil? || variable.discrete_values_and_weights.empty?
            raise 'no hash values and weight passed'
          end
          values, weights = variable.map_discrete_hash_to_array
          values.each do |val|
            instance = {}
            instance[variable.id.to_s.to_sym] = val
            selected_variables.each do |variable2|
              if variable != variable2
                instance[variable2.id.to_s.to_sym] = variable2.static_value
              end
            end
            samples << instance
          end
        end
      elsif @analysis.problem['algorithm']['in_measure_combinations'].casecmp('true').zero?
        logger.info 'In True'
        measure_list = []
        selected_variables.each do |var|
          measure_list << var.measure.id unless measure_list.include? var.measure.id
        end
        measure_list.each do |meas|
          meas_var_val = {}
          meas_var = []
          meas_var_num = []
          selected_variables.each do |var|
            if var.measure.id == meas
              values, weights = var.map_discrete_hash_to_array
              if @analysis.problem['algorithm']['include_baseline_in_combinations'].casecmp('true').zero?
                values << var.static_value
              end
              meas_var_val[var.id.to_s] = values
              meas_var << var.id
              meas_var_num << [0..(values.length - 1)][0].to_a
            end
          end
          # logger.info "meas_var_num: #{meas_var_num}; meas_var_val: #{meas_var_val}; meas_var: #{meas_var}"
          combinations = meas_var_num.first.product(*meas_var_num[1..-1])
          combinations.each do |combination|
            instance = {}
            combination.each_with_index do |value_ind, var_ind|
              instance[(meas_var[var_ind]).to_s.to_sym] = meas_var_val[meas_var[var_ind]][value_ind]
            end
            selected_variables.each do |var|
              instance[var.id.to_s.to_sym] = var.static_value unless meas_var.include? var.id
            end
            # logger.info "instance: #{instance}"
            sleep 1
            samples << instance
          end
        end
      else
        raise "Algorithm variable 'in_measure_combinations' was not set to valid values 'true' or 'false', instead '#{@analysis.problem['algorithm']['in_measure_combinations'].downcase}'"
      end
      # Add the datapoints to the database
      isample = 0
      samples.uniq.each do |sample| # do this in parallel
        isample += 1
        dp_name = "Autogenerated #{isample}"
        dp = @analysis.data_points.new(name: dp_name)
        dp.set_variable_values = sample
        dp.save!

        logger.info("Generated datapoint #{dp.name} for analysis #{@analysis.name}")
      end

    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      logger.info log_message
      @analysis.status_message = log_message
      @analysis.save!
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
