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
class AnalysisLibrary::Deoptim < AnalysisLibrary::Base
  include AnalysisLibrary::R::Core

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
    @analysis = Analysis.find(@analysis_id)

    # get the analysis and report that it is running
    @analysis_job = AnalysisLibrary::Core.initialize_analysis_job(@analysis, @analysis_job_id, @options)

    # reload the object (which is required) because the subdocuments (jobs) may have changed
    @analysis.reload

    # create an instance for R
    @r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                 APP_CONFIG['rserve_port'])
    logger.info 'Setting up R for Batch Run'
    @r.converse("setwd('#{APP_CONFIG['sim_root_path']}')")

    # TODO: fix statically setting the random seed
    @r.converse('set.seed(1979)')
    # R libraries needed for this algorithm
    @r.converse 'library(rjson)'
    @r.converse 'library(mco)'
    @r.converse 'library(DEoptim)'
    @r.converse 'library(doSNOW)'

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = ComputeNode.where(node_type: 'server').first.ip_address
    logger.info("Master ip: #{master_ip}")
    logger.info('Starting Batch Run')

    # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
    # that the run flag is true.

    # TODO: preflight check -- need to catch this in the analysis module
    if @analysis.problem['algorithm']['generations'].nil? || @analysis.problem['algorithm']['generations'] == 0
      raise 'Number of generations was not set or equal to zero (must be 1 or greater)'
    end

    if @analysis.problem['number_of_samples'].nil? || @analysis.problem['number_of_samples'] == 0
      raise 'Must have number of samples to discretize the parameter space'
    end

    pivot_array = Variable.pivot_array(@analysis.id)
    selected_variables = Variable.variables(@analysis.id)
    logger.info "Found #{selected_variables.count} variables to perturb"

    # discretize the variables using the LHS sampling method
    @r.converse("print('starting lhs to discretize the variables')")
    logger.info 'starting lhs to discretize the variables'

    lhs = AnalysisLibrary::R::Lhs.new(@r)
    samples, var_types = lhs.sample_all_variables(selected_variables, @analysis.problem['number_of_samples'])

    if samples.empty? || samples.size <= 1
      logger.info 'No variables were passed into the options, therefore exit'
      raise "Must have more than one variable to run algorithm.  Found #{samples.size} variables"
    end

    # Result of the parameter space will be column vectors of each variable
    logger.info "Samples are #{samples}"

    # Initialize some variables that are in the rescue/ensure blocks
    cluster = nil
    begin
      # Start up the cluster and perform the analysis
      cluster = AnalysisLibrary::R::Cluster.new(@r, @analysis.id)
      unless cluster.configure(master_ip)
        raise 'could not configure R cluster'
      end

      # Initialize each worker node
      worker_ips = ComputeNode.worker_ips
      logger.info "Worker node ips #{worker_ips}"

      logger.info 'Running initialize worker scripts'
      unless cluster.initialize_workers(worker_ips, @analysis.id)
        raise 'could not run initialize worker scripts'
      end

      if cluster.start(worker_ips)
        logger.info "Cluster Started flag is #{cluster.started}"
        # gen is the number of generations to calculate
        # varNo is the number of variables (ncol(vars))
        # popSize is the number of sample points in the variable (nrow(vars))
        logger.info("variable types are #{var_types}")
        @r.command(vars: samples.to_dataframe, vartypes: var_types, gen: @analysis.problem['algorithm']['generations']) do
          %{
            clusterEvalQ(cl,library(RMongo))
            clusterEvalQ(cl,library(rjson))

            for (i in 1:ncol(vars)){
              vars[,i] <- sort(vars[,i])
            }
            print(vars)
            print(vartypes)


            #f(x) takes a UUID (x) and runs the datapoint
            f <- function(x){
              mongo <- mongoDbConnect("#{AnalysisLibrary::Core.database_name}", host="#{master_ip}", port=27017)
              flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{run_flag:1}')
              if (flag["run_flag"] == "false" ){
                stop(options("show.error.messages"="Not TRUE"),"run flag is not TRUE")
              }
              dbDisconnect(mongo)

              ruby_command <- "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/bundle exec ruby"
              y <- paste(ruby_command," #{APP_CONFIG['sim_root_path']}/simulate_data_point.rb -a #{@analysis.id} -u ",x," -x #{@options[:run_data_point_filename]}",sep="")
              print(paste("R is calling system command as:",y))
              z <- system(y,intern=TRUE)
              print(paste("R returned system call with:",z))
              return(z)
            }
            clusterExport(cl,"f")

            #g(x) such that x is vector of variable values,
            #           create a datapoint from the vector of variable values x and return the new data point UUID
            #           create a UUID for that data_point and put in database
            #           call f(u) where u is UUID of data_point
            g <- function(x){
              ruby_command <- "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/bundle exec ruby"
              # convert the vector to comma separated values
              w = paste(x, collapse=",")
              y <- paste(ruby_command," #{APP_CONFIG['sim_root_path']}/#{@options[:create_data_point_filename]} -a #{@analysis.id} -v ",w, sep="")
              z <- system(y,intern=TRUE)
              j <- length(z)
              z

              # Call the simulate datapoint method
              f(z[j])

              data_point_directory <- paste("#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/data_point_",z[j],sep="")

              # save off the variables file (can be used later if number of vars gets too long)
              write.table(x, paste(data_point_directory,"/input_variables_from_r.data",sep=""),row.names = FALSE, col.names = FALSE)

              # read in the results from the objective function file
              # TODO: verify that the file exists
              # TODO: determine how to handle if the objective function value = nil/null
              object_file <- paste(data_point_directory,"/objectives.json",sep="")
              json <- fromJSON(file=object_file)
              obj <- NULL
              obj[1] <- as.numeric(json$objective_function_1)
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
              print("NSGA2 needs more than one variable")
              stop
            }
            varMin <- c(min(vars[,1]))
            varMax <- c(max(vars[,1]))
            for (i in 2:ncol(vars)){
              varMin <- rbind(varMin,c(min(vars[,i])))
              varMax <- rbind(varMax,c(max(vars[,i])))
            }
            print(paste("Number of generations set to:",gen))
            registerDoSNOW(cl)
            results <- DEoptim(g,lower=varMin, upper=varMax,control=list(itermax=gen,NP=100,parallelType=2, storepopfrom=1, storepopfreq=1))
            #results <- genoud(g,ncol(vars),pop.size=100,Domains=dom,boundary.enforcement=2,print.level=2,cluster=cl)
            #results <- nsga2NREL(cl=cl, fn=g, objDim=2, variables=vars[], vartype=vartypes, generations=gen, mprob=0.8)
            #results <- sfLapply(vars[,1], f)
            save(results, file="#{APP_CONFIG['sim_root_path']}/results_#{@analysis.id}.R")
          }
        end
      else
        raise 'could not start the cluster (most likely timed out)'
      end

    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      puts log_message
      @analysis.status_message = log_message
      @analysis.save!
    ensure
      # ensure that the cluster is stopped
      cluster.stop if cluster

      logger.info 'Running finalize worker scripts'
      unless cluster.finalize_workers(worker_ips, @analysis.id)
        raise 'could not run finalize worker scripts'
      end

      # Only set this data if the analysis was NOT called from another analysis
      unless @options[:skip_init]
        @analysis.end_time = Time.now
        @analysis.status = 'completed'
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
