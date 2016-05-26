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

class AnalysisLibrary::RgenoudLexical
  include AnalysisLibrary::Core
  include AnalysisLibrary::R

  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = {
      skip_init: false,
      run_data_point_filename: 'run_openstudio_workflow.rb',
      create_data_point_filename: 'create_data_point.rb',
      output_variables: [],
      problem: {
        random_seed: 1979,
        algorithm: {
          generations: 1,
          waitgenerations: 3,
          popsize: 30,
          boundaryenforcement: 2,
          bfgsburnin: 2,
          printlevel: 2,
          balance: false,
          solutiontolerance: 0.01,
          normtype: 'minkowski',
          ppower: 2,
          objective_functions: [],
          pgtol: 1e-1,
          factr: 4.5036e14,
          maxit: 5,
          epsilongradient: 1e-4
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
    Rails.logger.info 'Setting up R for genoud Run'
    @r.converse("setwd('#{APP_CONFIG['sim_root_path']}')")

    # TODO: deal better with random seeds
    @r.converse("set.seed(#{@analysis.problem['random_seed']})")
    # R libraries needed for this algorithm
    @r.converse 'library(rjson)'
    @r.converse 'library(mco)'
    @r.converse 'library(NRELmoo)'
    @r.converse 'library(rgenoud)'

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = ComputeNode.where(node_type: 'server').first.ip_address
    Rails.logger.info("Master ip: #{master_ip}")
    Rails.logger.info('Starting genoud Run')

    # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
    # that the run flag is true.

    # TODO: preflight check -- need to catch this in the analysis module
    if @analysis.problem['algorithm']['maxit'].nil? || @analysis.problem['algorithm']['maxit'] == 0
      raise 'Number of max iterations was not set or equal to zero (must be 1 or greater)'
    end

    if @analysis.problem['algorithm']['popsize'].nil? || @analysis.problem['algorithm']['popsize'] == 0
      raise 'Must have number of samples to discretize the parameter space'
    end

    # TODO: add test for not "minkowski", "maximum", "euclidean", "binary", "manhattan"
    # if @analysis.problem['algorithm']['normtype'] != "minkowski", "maximum", "euclidean", "binary", "manhattan"
    #  raise "P Norm must be non-negative"
    # end

    if @analysis.problem['algorithm']['ppower'] <= 0
      raise 'P Norm must be non-negative'
    end

    ug = @analysis.output_variables.uniq { |v| v['objective_function_group'] }
    Rails.logger.info "Number of objective function groups are #{ug.size}"
    if @analysis.output_variables.count { |v| v['objective_function'] == true } != @analysis.problem['algorithm']['objective_functions'].size
      raise 'number of objective functions must equal'
    end

    pivot_array = Variable.pivot_array(@analysis.id)
    selected_variables = Variable.variables(@analysis.id)
    Rails.logger.info "Found #{selected_variables.count} variables to perturb"

    # discretize the variables using the LHS sampling method
    @r.converse("print('starting lhs to discretize the variables')")
    Rails.logger.info 'starting lhs to discretize the variables'

    lhs = AnalysisLibrary::R::Lhs.new(@r)
    samples, var_types, mins_maxes, var_names = lhs.sample_all_variables(selected_variables, 3)

    if var_names.empty? || var_names.empty?
      Rails.logger.info 'No variables were passed into the options, therefore exit'
      raise "Must have at least one variable to run algorithm.  Found #{var_names.size} variables"
    end

    unless var_types.all? { |t| t.casecmp('continuous').zero? }
      Rails.logger.info 'Must have all continous variables to run algorithm, therefore exit'
      raise "Must have all continous variables to run algorithm.  Found #{var_types}"
    end

    Rails.logger.info "mins_maxes: #{mins_maxes}"
    Rails.logger.info "var_names: #{var_names}"

    # Result of the parameter space will be column vectors of each variable
    # Rails.logger.info "Samples are #{samples}"

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
      Rails.logger.info "Worker node ips #{worker_ips}"

      Rails.logger.info 'Running initialize worker scripts'
      unless cluster.initialize_workers(worker_ips, @analysis.id)
        raise 'could not run initialize worker scripts'
      end

      worker_ips = ComputeNode.worker_ips
      Rails.logger.info "Found the following good ips #{worker_ips}"

      if cluster.start(worker_ips)
        Rails.logger.info "Cluster Started flag is #{cluster.started}"
        # maxit is the max number of iterations to calculate
        # varNo is the number of variables (ncol(vars))
        # popsize is the number of sample points in the variable (nrow(vars))
        # epsilongradient is epsilon in numerical gradient calc

        # convert to float because the value is normally an integer and rserve/rserve-simpler only handles maxint
        @analysis.problem['algorithm']['factr'] = @analysis.problem['algorithm']['factr'].to_f
        @r.command(vartypes: var_types, varnames: var_names, varseps: mins_maxes[:eps], mins: mins_maxes[:min], maxes: mins_maxes[:max], normtype: @analysis.problem['algorithm']['normtype'], ppower: @analysis.problem['algorithm']['ppower'], objfun: @analysis.problem['algorithm']['objective_functions'], gen: @analysis.problem['algorithm']['generations'], popSize: @analysis.problem['algorithm']['popsize'], BFGSburnin: @analysis.problem['algorithm']['bfgsburnin'], boundaryEnforcement: @analysis.problem['algorithm']['boundaryenforcement'], printLevel: @analysis.problem['algorithm']['printlevel'], balance: @analysis.problem['algorithm']['balance'], solutionTolerance: @analysis.problem['algorithm']['solutiontolerance'], waitGenerations: @analysis.problem['algorithm']['waitgenerations'], maxit: @analysis.problem['algorithm']['maxit'], epsilongradient: @analysis.problem['algorithm']['epsilongradient'], factr: @analysis.problem['algorithm']['factr'], pgtol: @analysis.problem['algorithm']['pgtol'], uniquegroups: ug.size) do
          %{
            clusterEvalQ(cl,library(RMongo))
            clusterEvalQ(cl,library(rjson))
            clusterEvalQ(cl,library(R.utils))

            print(paste("objfun:",objfun))
            objDim <- length(objfun)
            print(paste("objDim:",objDim))
            print(paste("UniqueGroups:",uniquegroups))
            print(paste("normtype:",normtype))
            print(paste("ppower:",ppower))

            print(paste("min:",mins))
            print(paste("max:",maxes))

            clusterExport(cl,"objDim")
            clusterExport(cl,"normtype")
            clusterExport(cl,"ppower")
            clusterExport(cl,"uniquegroups")


            print(paste("vartypes:",vartypes))
            print(paste("varnames:",varnames))


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
              #print(paste("R is calling system command as:",y))
              z <- system(y,intern=TRUE)
              #print(paste("R returned system call with:",z))
              return(z)
            }
            clusterExport(cl,"f")

            #g(x) such that x is vector of variable values,
            #           create a data_point from the vector of variable values x and return the new data point UUID
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

              # Call the simulate data point method
              f(z[j])

              data_point_directory <- paste("#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/data_point_",z[j],sep="")

              # save off the variables file (can be used later if number of vars gets too long)
              write.table(x, paste(data_point_directory,"/input_variables_from_r.data",sep=""),row.names = FALSE, col.names = FALSE)

              # read in the results from the objective function file
              object_file <- paste(data_point_directory,"/objectives.json",sep="")
         tryCatch({
           res <- evalWithTimeout({
             json <- fromJSON(file=object_file)
           }, timeout=5);
           }, TimeoutException=function(ex) {
              cat(data_point_directory," No objectives.json: Timeout\n");
                   return(1e19)
              })
              #json <- fromJSON(file=object_file)
              obj <- NULL
              objvalue <- NULL
              objtarget <- NULL
              sclfactor <- NULL
              objgroup <- NULL
              group_count <- 1
              for (i in 1:objDim){
                objfuntemp <- paste("objective_function_",i,sep="")
                if (json[objfuntemp] != "NULL"){
                  objvalue[i] <- as.numeric(json[objfuntemp])
                } else {
                  objvalue[i] <- 1.0e19
                  cat(data_point_directory," Missing ", objfuntemp,"\n");
                }
                objfuntargtemp <- paste("objective_function_target_",i,sep="")
                if (json[objfuntargtemp] != "NULL"){
                  objtarget[i] <- as.numeric(json[objfuntargtemp])
                } else {
                  objtarget[i] <- 0.0
                }
                scalingfactor <- paste("scaling_factor_",i,sep="")
                sclfactor[i] <- 1.0
                if (json[scalingfactor] != "NULL"){
                  sclfactor[i] <- as.numeric(json[scalingfactor])
                  if (sclfactor[i] == 0.0) {
                    print(paste(scalingfactor," is ZERO, overwriting\n"))
                    sclfactor[i] = 1.0
                  }
                } else {
                  sclfactor[i] <- 1.0
                }
                objfungrouptemp <- paste("objective_function_group_",i,sep="")
                if (json[objfungrouptemp] != "NULL"){
                  objgroup[i] <- as.numeric(json[objfungrouptemp])
                } else {
                  objgroup[i] <- group_count
                  group_count <- group_count + 1
                }
              }
              options(digits=8)
              options(scipen=-2)
              print(paste("Objective function results are:",objvalue))
              print(paste("Objective function targets are:",objtarget))
              print(paste("Objective function scaling factors are:",sclfactor))
              objvalue <- objvalue / sclfactor
              objtarget <- objtarget / sclfactor

              ug <- length(unique(objgroup))
              if (ug != uniquegroups) {
                 print(paste("Json unique groups:",ug," not equal to Analysis unique groups",uniquegroups))
              }

              for (i in 1:ug){
                obj[i] <- dist(rbind(objvalue[objgroup==i],objtarget[objgroup==i]),method=normtype,p=ppower)
              }

              #for (i in 1:objDim){
              #  obj[i] <- dist(rbind(objvalue[i],objtarget[i]),method=normtype,p=ppower)
              #}
              print(paste("Objective function Norm:",obj))
              return(obj)
            }

            clusterExport(cl,"g")

            varMin <- mins
       varMax <- maxes
       varMean <- (mins+maxes)/2.0
       varDomain <- maxes - mins
       varEps <- varDomain*epsilongradient
       print(paste("varseps:",varseps))
       print(paste("varEps:",varEps))
       varEps <- ifelse(varseps!=0,varseps,varEps)
            print(paste("merged varEps:",varEps))
            varDom <- cbind(varMin,varMax)
            print(paste("varDom:",varDom))

            print("setup gradient")
            gn <- g
            clusterExport(cl,"gn")
            clusterExport(cl,"varEps")

            vectorGradient <- function(x, ...) { # Now use the cluster
           vectorgrad(func=gn, x=x, method="two", eps=varEps,cl=cl, debug=TRUE, ub=varMax, lb=varMin);
            }
            print(paste("Lower Bounds set to:",varMin))
            print(paste("Upper Bounds set to:",varMax))
            print(paste("Initial iterate set to:",varMean))
            print(paste("Length of variable domain:",varDomain))
            print(paste("factr set to:",factr))
            print(paste("pgtol set to:",pgtol))
            print(paste("BFGSburnin set to:",BFGSburnin))

            print(paste("Number of generations set to:",gen))
            #results <- genoud(fn=g, nvars=length(varMin), gr=vectorGradient, pop.size=popSize, max.generations=gen, Domains=varDom, boundary.enforcement=boundaryEnforcement, print.level=printLevel, cluster=cl, balance=balance, solution.tolerance=solutionTolerance, wait.generations=waitGenerations, control=list(trace=6, factr=factr, maxit=maxit, pgtol=pgtol))
            results <- genoud(fn=g, nvars=length(varMin), gr=vectorGradient, pop.size=popSize, lexical=objDim, BFGSburnin=BFGSburnin, max.generations=gen, Domains=varDom, boundary.enforcement=boundaryEnforcement, print.level=printLevel, cluster=cl, balance=balance, solution.tolerance=solutionTolerance, wait.generations=waitGenerations, control=list(trace=6, factr=factr, maxit=maxit, pgtol=pgtol))

       Rlog <- readLines('/var/www/rails/openstudio/log/Rserve.log')
       Rlog[grep('vartypes:',Rlog)]
            Rlog[grep('varnames:',Rlog)]
            Rlog[grep('<=',Rlog)]
            print(paste("popsize:",results$pop.size))
            print(paste("peakgeneration:",results$peakgeneration))
            print(paste("generations:",results$generations))
            print(paste("gradients:",results$gradients))
            print(paste("par:",results$par))
            print(paste("value:",results$value))
            flush.console()
            save(results, file="#{APP_CONFIG['sim_root_path']}/results_#{@analysis.id}.R")
          }
        end
      else
        raise 'could not start the cluster (most likely timed out)'
      end

      Rails.logger.info 'Running finalize worker scripts'
      unless cluster.finalize_workers(worker_ips, @analysis.id)
        raise 'could not run finalize worker scripts'
      end
    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      Rails.logger.error log_message
      @analysis.status_message = log_message
      @analysis.save!
    ensure
      # ensure that the cluster is stopped
      cluster.stop if cluster

      # Only set this data if the analysis was NOT called from another analysis
      unless @options[:skip_init]
        @analysis_job.end_time = Time.now
        @analysis_job.status = 'completed'
        @analysis_job.save!
        @analysis.reload
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
