# Non Sorting Genetic Algorithm
class Analysis::NsgaNrel
  include Analysis::R

  def initialize(analysis_id, options = {})
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
    Rails.logger.info(@options)
    @analysis_id = analysis_id
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
    @analysis.status = 'started'
    @analysis.end_time = nil
    @analysis.run_flag = true

    # add in the default problem/algorithm options into the analysis object
    # anything at at the root level of the options are not designed to override the database object.
    @analysis.problem = @options[:problem].deep_merge(@analysis.problem)

    # save other run information in another object in the analysis
    Rails.logger.info "Analysis type is #{@options['analysis_type']}"
    @analysis.run_options['nsga_nrel'] = @options.reject { |k, _| [:problem, :data_points, :output_variables].include?(k.to_sym) }
    # Clear out any former results on the analysis
    @analysis.results ||= {} # make sure that the analysis results is a hash and exists
    @analysis.results['nsga_nrel'] = {}

    # merge in the output variables and objective functions into the analysis object which are needed for problem execution
    @options[:output_variables].reverse.each { |v| @analysis.output_variables.unshift(v) unless @analysis.output_variables.include?(v) }
    @analysis.output_variables.uniq!

    # verify that the objective_functions are unique
    @analysis.problem['algorithm']['objective_functions'].uniq! if @analysis.problem['algorithm']['objective_functions']

    # some algorithm specific data to be stored in the database
    @analysis['iteration'] = @iteration

    # save the data
    @analysis.save!
    @analysis.reload # after saving the data (needed for some reason yet to be determined)

    # create an instance for R
    @r = Rserve::Simpler.new
    Rails.logger.info 'Setting up R for NSGA2 Run'
    @r.converse('setwd("/mnt/openstudio")')
    @r.converse('Sys.setenv(RUBYLIB="/usr/local/lib/ruby/site_ruby/2.0.0")')

    # TODO: deal better with random seeds
    @r.converse("set.seed(#{@analysis.problem['random_seed']})")
    # R libraries needed for this algorithm
    @r.converse 'library(rjson)'
    @r.converse 'library(mco)'
    @r.converse 'library(NRELmoo)'

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = ComputeNode.where(node_type: 'server').first.ip_address
    Rails.logger.info("Master ip: #{master_ip}")
    Rails.logger.info('Starting NSGA2 Run')

    # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
    # that the run flag is true.

    # TODO: preflight check -- need to catch this in the analysis module
    if @analysis.problem['algorithm']['generations'].nil? || @analysis.problem['algorithm']['generations'] == 0
      fail 'Number of generations was not set or equal to zero (must be 1 or greater)'
    end

    if @analysis.problem['algorithm']['number_of_samples'].nil? || @analysis.problem['algorithm']['number_of_samples'] == 0
      fail 'Must have number of samples to discretize the parameter space'
    end

    # TODO: add test for not "minkowski", "maximum", "euclidean", "binary", "manhattan"
    # if @analysis.problem['algorithm']['normtype'] != "minkowski", "maximum", "euclidean", "binary", "manhattan"
    #  raise "P Norm must be non-negative"
    # end

    if @analysis.problem['algorithm']['ppower'] <= 0
      fail 'P Norm must be non-negative'
    end

    if @analysis.problem['algorithm']['objective_functions'].nil? || @analysis.problem['algorithm']['objective_functions'].size < 2
      fail 'Must have at least two objective functions defined'
    end

    if @analysis.output_variables.empty? || @analysis.output_variables.size < 2
      fail 'Must have at least two output_variables'
    end

    objtrue = @analysis.output_variables.select { |v| v['objective_function'] == true }
    ug = objtrue.uniq { |v| v['objective_function_group'] }
    Rails.logger.info "Number of objective function groups are #{ug.size}"

    if @analysis.problem['algorithm']['exit_on_guideline14'] == 1
      @analysis.exit_on_guideline14 = true
    else
      @analysis.exit_on_guideline14 = false
    end
    @analysis.save!
    Rails.logger.info("exit_on_guideline14: #{@analysis.exit_on_guideline14}")

    if @analysis.output_variables.select { |v| v['objective_function'] == true }.size != @analysis.problem['algorithm']['objective_functions'].size
      fail 'number of objective functions must equal'
    end

    pivot_array = Variable.pivot_array(@analysis.id)
    selected_variables = Variable.variables(@analysis.id)
    Rails.logger.info "Found #{selected_variables.count} variables to perturb"

    # discretize the variables using the LHS sampling method
    @r.converse("print('starting lhs to discretize the variables')")
    Rails.logger.info 'starting lhs to discretize the variables'

    lhs = Analysis::R::Lhs.new(@r)
    samples, var_types, mins_maxes, var_names = lhs.sample_all_variables(selected_variables, @analysis.problem['algorithm']['number_of_samples'])

    # Result of the parameter space will be column vectors of each variable
    Rails.logger.info "Samples are #{samples}"

    Rails.logger.info "mins_maxes: #{mins_maxes}"
    Rails.logger.info "var_names: #{var_names}"
    Rails.logger.info("variable types are #{var_types}")

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
      if !cluster.configure(master_ip)
        fail 'could not configure R cluster'
      else
        Rails.logger.info 'Successfuly configured cluster'
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
      Rails.logger.info("Found the following good ips #{worker_ips}")

      cluster_started = cluster.start(worker_ips)
      Rails.logger.info("Time flag was set to #{cluster_started}")

      if cluster_started
        # gen is the number of generations to calculate
        # varNo is the number of variables (ncol(vars))
        # popSize is the number of sample points in the variable (nrow(vars))
        @r.command(vars: samples.to_dataframe, vartypes: var_types, varnames: var_names, mins: mins_maxes[:min], maxes: mins_maxes[:max],
                   normtype: @analysis.problem['algorithm']['normtype'], ppower: @analysis.problem['algorithm']['ppower'],
                   objfun: @analysis.problem['algorithm']['objective_functions'], gen: @analysis.problem['algorithm']['generations'],
                   toursize: @analysis.problem['algorithm']['toursize'], cprob: @analysis.problem['algorithm']['cprob'],
                   xoverdistidx: @analysis.problem['algorithm']['xoverdistidx'], mudistidx: @analysis.problem['algorithm']['mudistidx'],
                   mprob: @analysis.problem['algorithm']['mprob'], uniquegroups: ug.size) do
          %Q{
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

            for (i in 1:ncol(vars)){
              vars[,i] <- sort(vars[,i])
            }
            print(paste("vartypes:",vartypes))
            print(paste("varnames:",varnames))

            varfile <- function(x){
              if (!file.exists("/mnt/openstudio/analysis_#{@analysis.id}/varnames.json")){
               write.table(x, file="/mnt/openstudio/analysis_#{@analysis.id}/varnames.json", quote=FALSE,row.names=FALSE,col.names=FALSE)
              }
            }

            clusterExport(cl,"varfile")
            clusterExport(cl,"varnames")
            clusterEvalQ(cl,varfile(varnames))

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
              ruby_command <- "cd /mnt/openstudio && /usr/local/rbenv/shims/bundle exec ruby"
              # convert the vector to comma separated values
              w = paste(x, collapse=",")
              y <- paste(ruby_command," /mnt/openstudio/#{@options[:create_data_point_filename]} -a #{@analysis.id} -v ",w, sep="")
              z <- system(y,intern=TRUE)
              j <- length(z)
              z

              # Call the simulate data point method
            if (as.character(z[j]) == "NA") {
		      cat("UUID is NA \n");
              NAvalue <- .Machine$double.xmax
              return(NAvalue)
			} else {
		      try(f(z[j]), silent = TRUE)


              data_point_directory <- paste("/mnt/openstudio/analysis_#{@analysis.id}/data_point_",z[j],sep="")

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
               json <- toJSON(as.list(NULL))
               return(json)
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
              print(paste("Objective function results are:",objvalue))
              print(paste("Objective function targets are:",objtarget))
              print(paste("Objective function scaling factors are:",sclfactor))

              objvalue <- objvalue / sclfactor
              objtarget <- objtarget / sclfactor

              ug <- length(unique(objgroup))
              if (ug != uniquegroups) {
                 print(paste("Json unique groups:",ug," not equal to Analysis unique groups",uniquegroups))
                 write.table("unique groups", file="/mnt/openstudio/analysis_#{@analysis.id}/uniquegroups.err", quote=FALSE,row.names=FALSE,col.names=FALSE)
                 stop
              }

              for (i in 1:ug){
                obj[i] <- dist(rbind(objvalue[objgroup==i],objtarget[objgroup==i]),method=normtype,p=ppower)
              }

              #for (i in 1:objDim){
              #  obj[i] <- dist(rbind(objvalue[i],objtarget[i]),method=normtype,p=ppower)
              #}
              print(paste("Objective function Norm:",obj))

                mongo <- mongoDbConnect("os_dev", host="#{master_ip}", port=27017)
	        flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{exit_on_guideline14:1}')
	        print(paste("exit_on_guideline14: ",flag))
		if (flag["exit_on_guideline14"] == "true" ){
		  # read in the results from the objective function file
		  guideline_file <- paste(data_point_directory,"/run/CalibrationReports/guideline.json",sep="")
		  tryCatch({
		    res <- evalWithTimeout({
		       json <- fromJSON(file=guideline_file)
		       }, timeout=5);
		    }, TimeoutException=function(ex) {
		    cat(data_point_directory," No guideline.json file: Timeout\n");
		    json <- toJSON(as.list(NULL))
	            return(json)
                  })
                  guideline <- json[[1]]
                  for (i in 2:length(json)) guideline <- cbind(guideline,json[[i]])
                  print(paste("guideline: ",guideline))
                  print(paste("isTRUE(guideline): ",isTRUE(guideline)))
                  print(paste("all(guideline): ",all(guideline)))
                  if (all(guideline)){
                    #write final params to json file
                    varnames <- scan(file="/mnt/openstudio/analysis_#{@analysis.id}/varnames.json" , what=character())
                    answer <- paste('{',paste('"',varnames,'"',': ',x,sep='', collapse=','),'}',sep='')
                    write.table(answer, file="/mnt/openstudio/analysis_#{@analysis.id}/best_result.json", quote=FALSE,row.names=FALSE,col.names=FALSE)
                    convergenceflag <- paste('{',paste('"',"exit_on_guideline14",'"',': ',"true",sep='', collapse=','),'}',sep='')
                    write(convergenceflag, file="/mnt/openstudio/analysis_#{@analysis.id}/convergence_flag.json")
                    dbDisconnect(mongo)
                    stop(options("show.error.messages"="exit_on_guideline14"),"exit_on_guideline14")
                  }
		}
                dbDisconnect(mongo)

              return(obj)
              }
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

            print(paste("Number of generations set to:",gen))
            results <- nsga2NREL(cl=cl, fn=g, objDim=uniquegroups, variables=vars[], vartype=vartypes, generations=gen, tourSize=toursize, cprob=cprob, XoverDistIdx=xoverdistidx, MuDistIdx=mudistidx, mprob=mprob)
            save(results, file="/mnt/openstudio/analysis_#{@analysis.id}/results.R")
            #write final params to json file
            answer <- results$parameters
            write.table(answer, file="/mnt/openstudio/parameters_#{@analysis.id}.json", quote=FALSE,row.names=FALSE,col.names=FALSE)
            convergenceflag <- paste('{',paste('"',"exit_on_guideline14",'"',': ',"false",sep='', collapse=','),'}',sep='')
	    write(convergenceflag, file="/mnt/openstudio/analysis_#{@analysis.id}/convergence_flag.json")

          }
        end
      else
        fail 'could not start the cluster (most likely timed out)'
      end

    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      Rails.logger.error log_message
      @analysis.status_message = log_message
      @analysis.save!
    ensure
      # ensure that the cluster is stopped
      cluster.stop if cluster && cluster_started

      # Kill the downloading of data files process
      Rails.logger.info('Ensure block of analysis cleaning up any remaining processes')
      process.stop if process
      # Post process the results and jam into the database
      best_result_json = "/mnt/openstudio/analysis_#{@analysis.id}/best_result.json"
      if File.exist? best_result_json
        begin
          @analysis.results['nsga_nrel']['best_result'] = JSON.parse(File.read(best_result_json))
          @analysis.save!
        rescue => e
          Rails.logger.error 'Could not save post processed results for bestresult.json into the database'
        end
      else
        # find the best point based on the simulations

      end

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
