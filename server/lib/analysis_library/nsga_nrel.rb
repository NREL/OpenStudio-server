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

# TODO: Fix this for new queue

# Non Sorting Genetic Algorithm
class AnalysisLibrary::NsgaNrel < AnalysisLibrary::Base
  include AnalysisLibrary::R::Core

  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = {
        skip_init: false,
        run_data_point_filename: 'run_openstudio_workflow.rb',
        create_data_point_filename: 'create_data_point.rb',
        output_variables: [],
        problem: {
            random_seed: 1979,
            algorithm: {
                number_of_samples: 30,
                sample_method: 'individual_variables',
                generations: 1,
                toursize: 2,
                cprob: 0.7,
                xoverdistidx: 5,
                mudistidx: 10,
                mprob: 0.5,
                normtype: 'minkowski',
                ppower: 2,
                exit_on_guideline14: 0,
                objective_functions: []
            }
        }
    }.with_indifferent_access # make sure to set this because the params object from rails is indifferential
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

    # Make the analysis directory if it doesn't already exist
    FileUtils.mkdir_p analysis_dir(@analysis.id) unless Dir.exist? analysis_dir(@analysis.id)

    # create an instance for R
    @r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                 APP_CONFIG['rserve_port'])

    # Initialize some variables that are in the rescue/ensure blocks
    cluster = nil
    begin
      @r.converse("setwd('#{APP_CONFIG['sim_root_path']}')")

      # TODO: deal better with random seeds
      @r.converse("set.seed(#{@analysis.problem['random_seed']})")
      # R libraries needed for this algorithm
      @r.converse 'library(rjson)'
      @r.converse 'library(mco)'
      @r.converse 'library(NRELmoo)'

      master_ip = 'localhost'

      # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
      # that the run flag is true.

      # TODO: preflight check -- need to catch this in the analysis module
      if @analysis.problem['algorithm']['generations'].nil? || @analysis.problem['algorithm']['generations'] == 0
        raise 'Number of generations was not set or equal to zero (must be 1 or greater)'
      end

      if @analysis.problem['algorithm']['number_of_samples'].nil? || @analysis.problem['algorithm']['number_of_samples'] == 0
        raise 'Must have number of samples to discretize the parameter space'
      end

      # TODO: add test for not "minkowski", "maximum", "euclidean", "binary", "manhattan"

      if @analysis.problem['algorithm']['ppower'] <= 0
        raise 'P Norm must be non-negative'
      end

      if @analysis.problem['algorithm']['objective_functions'].nil? || @analysis.problem['algorithm']['objective_functions'].size < 2
        raise 'Must have at least two objective functions defined'
      end

      if @analysis.output_variables.empty? || @analysis.output_variables.size < 2
        raise 'Must have at least two output_variables'
      end

      objtrue = @analysis.output_variables.select { |v| v['objective_function'] == true }
      ug = objtrue.uniq { |v| v['objective_function_group'] }
      logger.info "Number of objective function groups are #{ug.size}"

      @analysis.exit_on_guideline14 = @analysis.problem['algorithm']['exit_on_guideline14'] == 1 ? true : false
      @analysis.save!
      logger.info("exit_on_guideline14: #{@analysis.exit_on_guideline14}")

      if @analysis.output_variables.count { |v| v['objective_function'] == true } != @analysis.problem['algorithm']['objective_functions'].size
        raise 'number of objective functions must equal'
      end

      pivot_array = Variable.pivot_array(@analysis.id)
      selected_variables = Variable.variables(@analysis.id)
      logger.info "Found #{selected_variables.count} variables to perturb"

      # discretize the variables using the LHS sampling method
      @r.converse("print('starting lhs to discretize the variables')")
      logger.info 'starting lhs to discretize the variables'

      lhs = AnalysisLibrary::R::Lhs.new(@r)
      samples, var_types, mins_maxes, var_names = lhs.sample_all_variables(selected_variables, @analysis.problem['algorithm']['number_of_samples'])

      if samples.empty? || samples.size <= 1
        logger.info 'No variables were passed into the options, therefore exit'
        raise "Must have more than one variable to run algorithm.  Found #{samples.size} variables"
      end

      # Result of the parameter space will be column vectors of each variable
      logger.info "Samples are #{samples}"

      logger.info "mins_maxes: #{mins_maxes}"
      logger.info "var_names: #{var_names}"
      logger.info("variable types are #{var_types}")


      # Start up the cluster and perform the analysis
      cluster = AnalysisLibrary::R::Cluster.new(@r, @analysis.id)
      unless cluster.configure
        raise 'could not configure R cluster'
      end

      worker_ips = {}
      worker_ips[:worker_ips] = ['localhost'] * 8

      logger.info "Found the following good ips #{worker_ips}"

      if cluster.start(worker_ips)
        logger.info "Cluster Started flag is #{cluster.started}"
        # gen is the number of generations to calculate
        # varNo is the number of variables (ncol(vars))
        # popSize is the number of sample points in the variable (nrow(vars))
        @r.command(master_ips: master_ip, ips: worker_ips[:worker_ips].uniq,
                   vars: samples.to_dataframe, vartypes: var_types,
                   varnames: var_names, mins: mins_maxes[:min],
                   maxes: mins_maxes[:max],
                   normtype: @analysis.problem['algorithm']['normtype'],
                   ppower: @analysis.problem['algorithm']['ppower'],
                   objfun: @analysis.problem['algorithm']['objective_functions'],
                   gen: @analysis.problem['algorithm']['generations'],
                   toursize: @analysis.problem['algorithm']['toursize'],
                   cprob: @analysis.problem['algorithm']['cprob'],
                   xoverdistidx: @analysis.problem['algorithm']['xoverdistidx'],
                   mudistidx: @analysis.problem['algorithm']['mudistidx'],
                   mprob: @analysis.problem['algorithm']['mprob'],
                   uniquegroups: ug.size) do
          %{
            rails_analysis_id = "#{@analysis.id}"
            rails_sim_root_path = "#{APP_CONFIG['sim_root_path']}"
            rails_ruby_bin_dir = "#{APP_CONFIG['ruby_bin_dir']}"
            rails_mongodb_name = "#{AnalysisLibrary::Core.database_name}"
            rails_mongodb_ip = "#{master_ip}"
            rails_run_filename = "#{@options[:run_data_point_filename]}"
            rails_create_dp_filename = "#{@options[:create_data_point_filename]}"
            rails_root_path = "#{Rails.root}"
            script_root_path = "#{Rails.root.join('lib/analysis_library/scripts')}"
            source('#{Rails.root.join('lib/analysis_library/scripts/nsga.R')}')
          }
        end
      else
        raise 'could not start the cluster (most likely timed out)'
      end

    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      logger.error log_message
      @analysis.status_message = log_message
      @analysis.save!
      @analysis_job.status = 'completed'
      @analysis_job.save!
      @analysis.reload
      @analysis.save!
    ensure
      # ensure that the cluster is stopped
      cluster.stop if cluster

      # Post process the results and jam into the database
      best_result_json = "#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/best_result.json"
      if File.exist? best_result_json
        begin
          logger.info('read best result json')
          temp2 = File.read(best_result_json)
          temp = JSON.parse(temp2, symbolize_names: true)
          logger.info("temp: #{temp}")
          @analysis.results[@options[:analysis_type]]['best_result'] = temp
          @analysis.save!
          logger.info("analysis: #{@analysis.results}")
        rescue => e
          logger.error 'Could not save post processed results for bestresult.json into the database'
        end
      end

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
end
