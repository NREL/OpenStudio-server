# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# R version of GA
class AnalysisLibrary::Gaisl < AnalysisLibrary::Base
  include AnalysisLibrary::R::Core

  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = ActiveSupport::HashWithIndifferentAccess.new(
      skip_init: false,
      run_data_point_filename: 'run_openstudio_workflow.rb',
      create_data_point_filename: 'create_data_point.rb',
      output_variables: [],
      problem: {
        algorithm: {
          popSize: 30,
          run: 2,
          maxFitness: 0.01,
          pcrossover: 0.8,
          pmutation: 0.1,
          elitism: 0.05,
          maxiter: 100,
          numIslands: 4,
          migrationRate: 0.1,
          migrationInterval: 10,
          norm_type: 'minkowski',
          p_power: 2,
          exit_on_guideline_14: 0,
          objective_functions: [],
          epsilon_gradient: 1e-4,
          debug_messages: 0,
          failed_f_value: 1e18,
          seed: nil
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
    logger.info 'Setting up R for GA Run'
    # Initialize some variables that are in the rescue/ensure blocks
    cluster = nil
    begin
      @r.converse("setwd('#{APP_CONFIG['sim_root_path']}')")

      if !@analysis.problem['algorithm']['seed'].nil? && (@analysis.problem['algorithm']['seed'].is_a? Numeric)
        logger.info "Setting R base random seed to #{@analysis.problem['algorithm']['seed']}"
        @r.converse("set.seed(#{@analysis.problem['algorithm']['seed']})")
      end
      # R libraries needed for this algorithm
      @r.converse 'library(rjson)'
      @r.converse 'library(R.utils)'
      @r.converse 'library(parallel)'
      @r.converse 'library(doParallel)'
      @r.converse 'library(NRELGA)'

      # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
      # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

      master_ip = 'localhost'

      logger.info("Master ip: #{master_ip}")
      logger.info('Starting GA Isl Run')

      # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
      # that the run flag is true.

      # TODO: preflight check -- need to catch this in the analysis module
      if @analysis.problem['algorithm']['maxiter'].nil? || (@analysis.problem['algorithm']['maxiter']).zero?
        raise 'Number of max iterations was not set or equal to zero (must be 1 or greater)'
      end

      if @analysis.problem['algorithm']['popSize'].nil? || (@analysis.problem['algorithm']['popSize']).zero?
        raise 'Must have number of samples to discretize the parameter space'
      end

      if @analysis.problem['algorithm']['elitism'] < 0 || @analysis.problem['algorithm']['elitism'] > 1
        raise 'elitism must be 0 <= elitism <= 1'
      end

      if @analysis.problem['algorithm']['pcrossover'] < 0 || @analysis.problem['algorithm']['pcrossover'] > 1
        raise 'pcrossover must be 0 <= pcrossover <= 1'
      end

      if @analysis.problem['algorithm']['pmutation'] < 0 || @analysis.problem['algorithm']['pmutation'] > 1
        raise 'pmutation must be 0 <= pmutation <= 1'
      end

      # TODO: add test for not "minkowski", "maximum", "euclidean", "binary", "manhattan"
      # if @analysis.problem['algorithm']['norm_type'] != "minkowski", "maximum", "euclidean", "binary", "manhattan"
      #  raise "P Norm must be non-negative"
      # end

      if @analysis.problem['algorithm']['p_power'] <= 0
        raise 'P Norm must be non-negative'
      end

      # exit on guideline 14 is no longer true/false.  its 0,1,2,3
      # @analysis.exit_on_guideline_14 = @analysis.problem['algorithm']['exit_on_guideline_14'] == 1 ? true : false
      if [0, 1, 2, 3].include? @analysis.problem['algorithm']['exit_on_guideline_14']
        @analysis.exit_on_guideline_14 = @analysis.problem['algorithm']['exit_on_guideline_14'].to_i
        logger.info "exit_on_guideline_14 is #{@analysis.exit_on_guideline_14}"
      else
        @analysis.exit_on_guideline_14 = 0
        logger.info "exit_on_guideline_14 is forced to #{@analysis.exit_on_guideline_14}"
      end
      @analysis.save!
      logger.info("exit_on_guideline_14: #{@analysis.exit_on_guideline_14}")

      @analysis.problem['algorithm']['objective_functions'] = [] unless @analysis.problem['algorithm']['objective_functions']
      @analysis.save!
      logger.info("exit_on_guideline_14: #{@analysis.exit_on_guideline_14}")

      # check to make sure there are objective functions
      if @analysis.output_variables.count { |v| v['objective_function'] == true }.zero?
        raise 'No objective functions defined'
      end

      # find the total number of objective functions
      if @analysis.output_variables.count { |v| v['objective_function'] == true } != @analysis.problem['algorithm']['objective_functions'].size
        raise 'Number of objective functions must equal between the output_variables and the problem definition'
      end

      pivot_array = Variable.pivot_array(@analysis.id, @r)
      logger.info "pivot_array: #{pivot_array}"
      selected_variables = Variable.variables(@analysis.id)
      logger.info "Found #{selected_variables.count} variables to perturb"

      # discretize the variables using the LHS sampling method
      @r.converse("print('starting lhs to discretize the variables')")
      logger.info 'starting lhs to discretize the variables'

      lhs = AnalysisLibrary::R::Lhs.new(@r)
      samples, var_types, mins_maxes, var_names = lhs.sample_all_variables(selected_variables, 3)

      # Result of the parameter space will be column vectors of each variable
      logger.info "Samples are #{samples}"
      logger.info "mins_maxes: #{mins_maxes}"
      logger.info "var_names: #{var_names}"
      logger.info("variable types are #{var_types}")

      if samples.empty? || samples.size <= 1
        logger.info 'No variables were passed into the options, therefore exit'
        raise "Must have more than one variable to run algorithm.  Found #{samples.size} variables"
      end

      if var_names.empty? || var_names.empty?
        logger.info 'No variables were passed into the options, therefore exit'
        raise "Must have at least one variable to run algorithm.  Found #{var_names.size} variables"
      end

      unless var_types.all? { |t| t.casecmp('continuous').zero? }
        logger.info 'Must have all continous variables to run algorithm, therefore exit'
        raise "Must have all continous variables to run algorithm.  Found #{var_types}"
      end

      # Start up the cluster and perform the analysis
      # cluster = AnalysisLibrary::R::Cluster.new(@r, @analysis.id)
      # unless cluster.configure
      #  raise 'could not configure R cluster'
      # end

      @r.converse("cat('max_queued_jobs: #{APP_CONFIG['max_queued_jobs']}')")
      worker_ips = {}
      if @analysis.problem['algorithm']['max_queued_jobs']
        if @analysis.problem['algorithm']['max_queued_jobs'] == 0
          logger.info 'MAX_QUEUED_JOBS is 0'
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

      # logger.info "Cluster Started flag is #{cluster.started}"
      # maxiter is the max number of iterations to calculate
      # varNo is the number of variables (ncol(vars))
      # popSize is the number of sample points in the variable (nrow(vars))
      # epsilongradient is epsilon in numerical gradient calc

      # convert to float because the value is normally an integer and rserve/rserve-simpler only handles maxint
      @analysis.problem['algorithm']['failed_f_value'] = @analysis.problem['algorithm']['failed_f_value'].to_f
      @r.command(master_ips: master_ip,
                 ips: worker_ips[:worker_ips],
                 vartypes: var_types,
                 varnames: var_names,
                 varseps: mins_maxes[:eps],
                 mins: mins_maxes[:min],
                 maxes: mins_maxes[:max],
                 normtype: @analysis.problem['algorithm']['norm_type'],
                 ppower: @analysis.problem['algorithm']['p_power'],
                 objfun: @analysis.problem['algorithm']['objective_functions'],
                 popSize: @analysis.problem['algorithm']['popSize'],
                 run: @analysis.problem['algorithm']['run'],
                 maxFitness: @analysis.problem['algorithm']['maxFitness'],
                 maxiter: @analysis.problem['algorithm']['maxiter'],
                 pcrossover: @analysis.problem['algorithm']['pcrossover'],
                 pmutation: @analysis.problem['algorithm']['pmutation'],
                 elitism: @analysis.problem['algorithm']['elitism'],
                 numIslands: @analysis.problem['algorithm']['numIslands'],
                 migrationInterval: @analysis.problem['algorithm']['migrationInterval'],
                 migrationRate: @analysis.problem['algorithm']['migrationRate'],
                 epsilongradient: @analysis.problem['algorithm']['epsilon_gradient'],
                 debug_messages: @analysis.problem['algorithm']['debug_messages'],
                 failed_f: @analysis.problem['algorithm']['failed_f_value']) do
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
            rails_exit_guideline_14 = "#{@analysis.exit_on_guideline_14}"

            init <- function(x){
                ruby_command <- "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/bundle exec ruby"
                y <- paste(ruby_command," #{APP_CONFIG['sim_root_path']}/worker_init_final.rb -h #{APP_CONFIG['os_server_host_url']} -a #{@analysis_id} -s 'initialize'",sep="")
                print(paste("Run command",y))
                z <- system(y,intern=TRUE)
                z
            }
            init
            source(paste(r_scripts_path,'/functions.R',sep=''))
            source(paste(r_scripts_path,'/gaisl.R',sep=''))
          }
      end
      logger.info 'Returned from rserve gaisl block'
    # TODO: find any results of the algorithm and save to the analysis
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
      logger.info 'Executing gaisl.rb ensure block'
      begin
        # cluster.stop if cluster
      rescue StandardError, ScriptError, NoMemoryError => e
        # logger.error "Error executing cluster.stop, #{e.message}, #{e.backtrace}"
      end
      # logger.info 'Successfully executed cluster.stop'

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
        rescue StandardError => e
          logger.error 'Could not save post processed results for bestresult.json into the database'
        end
      end

      # Post process the results and jam into the database
      converge_flag_json = "#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/convergence_flag.json"
      if File.exist? converge_flag_json
        begin
          logger.info('read converge_flag.json')
          temp2 = File.read(converge_flag_json)
          temp = JSON.parse(temp2, symbolize_names: true)
          logger.info("temp: #{temp}")
          @analysis.results[@options[:analysis_type]]['convergence_flag'] = temp
          @analysis.save!
          logger.info("analysis: #{@analysis.results}")
        rescue StandardError => e
          logger.error 'Could not save post processed results for converge_flag.json into the database'
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
