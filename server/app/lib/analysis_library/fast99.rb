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

#Fast99 Screening and Sensitivity method
class AnalysisLibrary::Fast99 < AnalysisLibrary::Base
  include AnalysisLibrary::R::Core

  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = ActiveSupport::HashWithIndifferentAccess.new(
        {
            skip_init: false,
            run_data_point_filename: 'run_openstudio_workflow.rb',
            create_data_point_filename: 'create_data_point.rb',
            output_variables: [],
            problem: {
                algorithm: {
                    n: 66,
                    M: 4,
                    norm_type: 'minkowski',
                    p_power: 2,
                    debug_messages: 0,
                    failed_f_value: 1e18,
                    objective_functions: [],
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

    # Make the analysis directory if it doesn't already exist
    FileUtils.mkdir_p analysis_dir(@analysis.id) unless Dir.exist? analysis_dir(@analysis.id)

    # create an instance for R
    @r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                 APP_CONFIG['rserve_port'])
    logger.info 'Setting up R for Fast99 Run'
    # Initialize some variables that are in the rescue/ensure blocks
    cluster = nil
    begin
      @r.converse("setwd('#{APP_CONFIG['sim_root_path']}')")
      @r.converse(" print(paste('getwd:',getwd()))")
      # make this a core method
      if !@analysis.problem['algorithm']['seed'].nil? && (@analysis.problem['algorithm']['seed'].is_a? Numeric)
        logger.info "Setting R base random seed to #{@analysis.problem['algorithm']['seed']}"
        @r.converse("set.seed(#{@analysis.problem['algorithm']['seed']})")
      end
      # R libraries needed for this algorithm
      @r.converse 'library(rjson)'
      @r.converse 'library(sensitivity)'
      @r.converse 'library(ggplot2)'
      @r.converse 'library(cowplot)'
      @r.converse 'library(ggsci)'
      @r.converse 'library(reshape2)'

      # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
      # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

      master_ip = 'localhost'

      logger.info("Master ip: #{master_ip}")
      logger.info('Starting Fast99 Run')

      # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
      # that the run flag is true.

      # TODO: preflight check -- need to catch this in the analysis module
      if @analysis.problem['algorithm']['n'].nil? || (@analysis.problem['algorithm']['n']).zero?
        raise 'Value for n was not set or equal to zero (must be 1 or greater)'
      end

      if (4*@analysis.problem['algorithm']['M']*@analysis.problem['algorithm']['M']+2) <= (@analysis.problem['algorithm']['n'])
        logger.info 'Value for n was not > 4*M^2+2, will adjust value'
      end

      @analysis.problem['algorithm']['objective_functions'] = [] unless @analysis.problem['algorithm']['objective_functions']
      @analysis.save!

      objtrue = @analysis.output_variables.select {|v| v['objective_function'] == true}
      ug = objtrue.uniq {|v| v['objective_function_group']}
      logger.info "Number of objective function groups are #{ug.size}"
      obj_names = []
      ug.each do |var|
        obj_names << var['display_name_short']
      end
      logger.info "Objective function names #{obj_names}"

      pivot_array = Variable.pivot_array(@analysis.id, @r)
      logger.info "pivot_array: #{pivot_array}"
      selected_variables = Variable.variables(@analysis.id)
      logger.info "Found #{selected_variables.count} variables to perturb"

      var_display_names = []
      selected_variables.each do |var|
        var_display_names << var.display_name_short
      end
      logger.info "Variable display names #{var_display_names}"

      # discretize the variables using the LHS sampling method
      @r.converse("print('starting lhs to get min/max')")
      logger.info 'starting lhs to discretize the variables'

      lhs = AnalysisLibrary::R::Lhs.new(@r)
      samples, var_types, mins_maxes, var_names = lhs.sample_all_variables(selected_variables, 2 * selected_variables.count)

      # Result of the parameter space will be column vectors of each variable
      logger.info "Samples are #{samples}"
      logger.info "mins_maxes: #{mins_maxes}"
      logger.info "var_names: #{var_names}"
      logger.info("variable types are #{var_types}")

      if samples.empty? || samples.size <= 1
        logger.info 'No variables were passed into the options, therefore exit'
        raise "Must have more than one variable to run algorithm.  Found #{samples.size} variables"
      end

      # Start up the cluster and perform the analysis
      cluster = AnalysisLibrary::R::Cluster.new(@r, @analysis.id)
      unless cluster.configure
        raise 'could not configure R cluster'
      end

      @r.converse("cat('max_queued_jobs: #{APP_CONFIG['max_queued_jobs']}')")
      worker_ips = {}
      if @analysis.problem['algorithm']['max_queued_jobs']
        if @analysis.problem['algorithm']['max_queued_jobs'] == 0
          logger.info "MAX_QUEUED_JOBS is 0"
          raise 'MAX_QUEUED_JOBS is 0'
        elsif @analysis.problem['algorithm']['max_queued_jobs'] > 0
          worker_ips[:worker_ips] = ['localhost'] * @analysis.problem['algorithm']['max_queued_jobs']
          logger.info "Starting R queue to hold #{@analysis.problem['algorithm']['max_queued_jobs']} jobs"
        end
      elsif !APP_CONFIG['max_queued_jobs'].nil?
        worker_ips[:worker_ips] = ['localhost'] * APP_CONFIG['max_queued_jobs'].to_i
        logger.info "Starting R queue to hold #{APP_CONFIG['max_queued_jobs']} jobs"
      else
        raise 'could not start the cluster (cluster size not set correctly)'
      end
      if cluster.start(worker_ips)
        logger.info "Cluster Started flag is #{cluster.started}"

        # convert to float because the value is normally an integer and rserve/rserve-simpler only handles maxint
        @analysis.problem['algorithm']['failed_f_value'] = @analysis.problem['algorithm']['failed_f_value'].to_f
        @r.command(master_ips: master_ip,
                   ips: worker_ips[:worker_ips].uniq,
                   vars: samples.to_dataframe,
                   vartypes: var_types,
                   varnames: var_names,
                   mins: mins_maxes[:min],
                   maxes: mins_maxes[:max],
                   n: @analysis.problem['algorithm']['n'],
                   M: @analysis.problem['algorithm']['M'],
                   normtype: @analysis.problem['algorithm']['norm_type'],
                   ppower: @analysis.problem['algorithm']['p_power'],
                   objfun: @analysis.problem['algorithm']['objective_functions'],
                   debug_messages: @analysis.problem['algorithm']['debug_messages'],
                   failed_f: @analysis.problem['algorithm']['failed_f_value'],
                   vardisplaynames: var_display_names, 
                   objnames: obj_names,
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
            rails_host = "#{APP_CONFIG['os_server_host_url']}"
            r_scripts_path = "#{APP_CONFIG['r_scripts_path']}"
            whoami <- system('whoami', intern = TRUE)
            print(paste("Fast99.rb whoami:", whoami))
            hostname <- system('hostname', intern = TRUE)
            print(paste("Fast99.rb hostname:", hostname))
            rails_exit_guideline_14 = 0
            source(paste(r_scripts_path,'/fast99.R',sep=''))
        }
        end
        logger.info 'Returned from rserve Fast99 block'
      else
        raise 'could not start the cluster (most likely timed out)'
      end
    rescue StandardError, ScriptError, NoMemoryError => e
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
      logger.info 'Executing rgenound.rb ensure block'
      begin
        cluster.stop if cluster
      rescue StandardError, ScriptError, NoMemoryError => e
        logger.error "Error executing cluster.stop, #{e.message}, #{e.backtrace}"
      end
      logger.info 'Successfully executed cluster.stop'

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
