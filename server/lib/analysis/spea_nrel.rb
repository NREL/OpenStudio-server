# Non Sorting Genetic Algorithm
class Analysis::SpeaNrel
  include Analysis::R

  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = {
      skip_init: false,
      run_data_point_filename: 'run_openstudio_workflow.rb',
      create_data_point_filename: 'create_data_point.rb',
      output_variables: [
        {
          display_name: 'Total Site Energy (EUI)',
          name: 'total_energy',
          objective_function: true,
          objective_function_index: 0,
          index: 0
        },
        {
          display_name: 'Total Life Cycle Cost',
          name: 'total_life_cycle_cost',
          objective_function: true,
          objective_function_index: 1,
          index: 1
        }
      ],
      problem: {
        algorithm: {
          generations: 1,
          tourSize: 2,
          cprob: 0.7,
          cidx: 5,
          midx: 10,
          mprob: 0.5,
          objective_functions: %w(total_energy total_life_cycle_cost)
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
    # add into delayed job
    require 'rserve/simpler'
    require 'uuid'
    require 'childprocess'

    # get the analysis and report that it is running
    @analysis = Analysis.find(@analysis_id)
    @analysis_job = Job.find(@analysis_job_id)
    @analysis.run_flag = true

    # add in the default problem/algorithm options into the analysis object
    # anything at at the root level of the options are not designed to override the database object.
    @analysis.problem = @options[:problem].deep_merge(@analysis.problem)

    # save other run information in another object in the analysis
    # save other run information in another object in the analysis
    @analysis_job.start_time = Time.now
    @analysis_job.status = 'started'
    @analysis_job.run_options =  @options.reject { |k, _| [:problem, :data_points, :output_variables].include?(k.to_sym) }
    @analysis_job.save!

    # Clear out any former results on the analysis
    @analysis.results ||= {} # make sure that the analysis results is a hash and exists
    @analysis.results[self.class.to_s.split('::').last.underscore] = {}

    # save all the changes into the database and reload the object (which is required)
    @analysis.save!
    @analysis.reload

    # merge in the output variables and objective functions into the analysis object which are needed for problem execution
    @options[:output_variables].reverse.each { |v| @analysis.output_variables.unshift(v) unless @analysis.output_variables.include?(v) }
    @analysis.output_variables.uniq!

    # verify that the objective_functions are unique
    @analysis.problem['algorithm']['objective_functions'].uniq! if @analysis.problem['algorithm']['objective_functions']

    # some algorithm specific data to be stored in the database
    @analysis['iteration'] = @iteration

    # save the algorithm specific updates
    @analysis.save!
    @analysis.reload

    # create an instance for R
    @r = Rserve::Simpler.new
    Rails.logger.info 'Setting up R for Batch Run'
    @r.converse('setwd("/mnt/openstudio")')
    @r.converse('set.seed(1979)')
    # R libraries needed for this algorithm
    @r.converse 'library(rjson)'
    @r.converse 'library(mco)'
    @r.converse 'library(NRELmoo)'

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = ComputeNode.where(node_type: 'server').first.ip_address
    Rails.logger.info("Master ip: #{master_ip}")
    Rails.logger.info('Starting Batch Run')

    # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
    # that the run flag is true.

    # TODO: preflight check -- need to catch this in the analysis module
    if @analysis.problem['algorithm']['generations'].nil? || @analysis.problem['algorithm']['generations'] == 0
      fail 'Number of generations was not set or equal to zero (must be 1 or greater)'
    end

    if @analysis.problem['number_of_samples'].nil? || @analysis.problem['number_of_samples'] == 0
      fail 'Must have number of samples to discretize the parameter space'
    end

    pivot_array = Variable.pivot_array(@analysis.id)
    selected_variables = Variable.variables(@analysis.id)
    Rails.logger.info "Found #{selected_variables.count} variables to perturb"

    # discretize the variables using the LHS sampling method
    @r.converse("print('starting lhs to discretize the variables')")
    Rails.logger.info 'starting lhs to discretize the variables'

    lhs = Analysis::R::Lhs.new(@r)
    samples, var_types = lhs.sample_all_variables(selected_variables, @analysis.problem['number_of_samples'])

    # Result of the parameter space will be column vectors of each variable
    Rails.logger.info "Samples are #{samples}"

    # Initialize some variables that are in the rescue/ensure blocks
    cluster_started = false
    cluster = nil
    process = nil
    begin
      if samples.empty? || samples.size <= 1
        Rails.logger.info 'No variables were passed into the options, therefore exit'
        fail "Must have more than one variable to run algorithm.  Found #{samples.size} variables"
      end

      # Start up the cluster and perform the analysis
      cluster = Analysis::R::Cluster.new(@r, @analysis.id)
      unless cluster.configure(master_ip)
        fail 'could not configure R cluster'
      end

      # Before kicking off the Analysis, make sure to setup the downloading of the files child process
      process = ChildProcess.build('/usr/local/rbenv/shims/bundle', 'exec', 'rake', "datapoints:download[#{@analysis.id}]", "RAILS_ENV=#{Rails.env}")
      # log_file = File.join(Rails.root,"log/download.log")
      # Rails.logger.info("Log file is: #{log_file}")
      process.io.inherit!
      # process.io.stdout = process.io.stderr = File.open(log_file,'a+')
      process.cwd = Rails.root # set the child's working directory where the bundler will execute
      Rails.logger.info('Starting Child Process')
      process.start

      worker_ips = ComputeNode.worker_ips
      Rails.logger.info "Found the following good ips #{worker_ips}"

      cluster_started = cluster.start(worker_ips)
      Rails.logger.info "Time flag was set to #{cluster_started}"

      if cluster_started
        # gen is the number of generations to calculate
        # varNo is the number of variables (ncol(vars))
        # popSize is the number of sample points in the variable (nrow(vars))
        Rails.logger.info("variable types are #{var_types}")
        @r.command(vars: samples.to_dataframe, vartypes: var_types, gen: @analysis.problem['algorithm']['generations'], tourSize: @analysis.problem['algorithm']['tourSize'], cprob: @analysis.problem['algorithm']['cprob'], cidx: @analysis.problem['algorithm']['cidx'], midx: @analysis.problem['algorithm']['midx'], mprob: @analysis.problem['algorithm']['mprob']) do
          %Q{
            clusterEvalQ(cl,library(RMongo))
            clusterEvalQ(cl,library(rjson))

            for (i in 1:ncol(vars)){
              vars[,i] <- sort(vars[,i])
            }
            print(vars)
            print(vartypes)


            #f(x) takes a UUID (x) and runs the datapoint
            f <- function(x){
              mongo <- mongoDbConnect("os_dev", host="#{master_ip}", port=27017)
              flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{run_flag:1}')
              if (flag["run_flag"] == "false" ){
                stop(options("show.error.messages"="Not TRUE"),"run flag is not TRUE")
              }
              dbDisconnect(mongo)

              ruby_command <- "cd /mnt/openstudio && /usr/local/rbenv/shims/bundle exec ruby"
              if ("#{@analysis.use_shm}" == "true"){
                y <- paste(ruby_command," /mnt/openstudio/simulate_data_point.rb -a #{@analysis.id} -u ",x," -x #{@options[:run_data_point_filename]} --run-shm",sep="")
              } else {
                y <- paste(ruby_command," /mnt/openstudio/simulate_data_point.rb -a #{@analysis.id} -u ",x," -x #{@options[:run_data_point_filename]}",sep="")
              }
              print(paste("R is calling system command as:",y))
              z <- system(y,intern=TRUE)
              print(paste("R returned system call with:",z))
              return(z)
            }
            clusterExport(cl,"f")

            #g(x) such that x is vector of variable values,
            #           create a data_point from the vector of variable values x and return the new data point UUID
            #           create a UUID for that data_point and put in database
            #           call f(u) where u is UUID of data_point
            g <- function(x){
              ruby_command <- "cd /mnt/openstudio && /usr/local/rbenv/shims/bundle exec ruby"
              # convert the vector to comma separated values
              w = paste(x, collapse=",")
              y <- paste(ruby_command," /mnt/openstudio/#{@options[:create_data_point_filename]} -a #{@analysis.id} -v ",w, sep="")
              z <- system(y,intern=TRUE)
              j <- length(z)
              z

              # Call the simulate data point method
              f(z[j])

              data_point_directory <- paste("/mnt/openstudio/analysis_#{@analysis.id}/data_point_",z[j],sep="")

              # save off the variables file (can be used later if number of vars gets too long)
              write.table(x, paste(data_point_directory,"/input_variables_from_r.data",sep=""),row.names = FALSE, col.names = FALSE)

              # read in the results from the objective function file
              # TODO: verify that the file exists
              # TODO: determine how to handle if the objective function value = nil/null
              object_file <- paste(data_point_directory,"/objectives.json",sep="")
              json <- fromJSON(file=object_file)
              obj <- rep(NA,2)
              obj[1] <- as.numeric(json$objective_function_1)
              obj[2] <- as.numeric(json$objective_function_2)
              print(paste("Objective function results are:",obj))
              return(obj)
            }

            clusterExport(cl,"g")

            if (nrow(vars) == 1) {
              print("not sure what to do with only one datapoint so adding an NA")
              vars <- rbind(vars, c(NA))
            }
            if (nrow(vars) == 0) {
              print("not sure what to do with no datapoint so adding an NA")
              vars <- rbind(vars, c(NA))
              vars <- rbind(vars, c(NA))
            }

            print(nrow(vars))
            print(ncol(vars))
            if (ncol(vars) == 1) {
              print("SPEA2 needs more than one variable")
              stop
            }

            print(paste("Number of generations set to:",gen))
            results <- spea2NREL(cl=cl, fn=g, objDim=2, variables=vars[], vartype=vartypes, generations=gen, tourSize=tourSize, cprob=cprob, cidx=cidx, mprob=mprob, midx=midx)
            #results <- sfLapply(vars[,1], f)
            save(results, file="/mnt/openstudio/spea2_#{@analysis.id}.R")
          }

        end
      else
        fail 'could not start the cluster (most likely timed out)'
      end

    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      puts log_message
      @analysis.status_message = log_message
      @analysis.save!
    ensure
      # ensure that the cluster is stopped
      cluster.stop if cluster && cluster_started

      # Kill the downloading of data files process
      Rails.logger.info('Ensure block of analysis cleaning up any remaining processes')
      process.stop if process

      # Do one last check if there are any data points that were not downloaded
      Rails.logger.info('Trying to download any remaining files from worker nodes')
      @analysis.finalize_data_points

      # Only set this data if the analysis was NOT called from another analysis
      unless @options[:skip_init]
        @analysis.end_time = Time.now
        @analysis.status = 'completed'
      end

      @analysis.save!

      Rails.logger.info "Finished running analysis '#{self.class.name}'"
    end
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    1
  end
end
