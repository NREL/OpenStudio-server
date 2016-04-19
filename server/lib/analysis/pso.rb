# Non Sorting Genetic Algorithm
class Analysis::Pso
  include Analysis::Core
  include Analysis::R

  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = {
      skip_init: false,
      run_data_point_filename: 'run_openstudio_workflow.rb',
      create_data_point_filename: 'create_data_point.rb',
      output_variables: [],
      problem: {
        random_seed: 1979,
        algorithm: {
          npart: 0,
          maxfn: 100,
          maxit: 20,
          abstol: 1e-2,
          reltol: 1e-2,
          method: 'spso2011',
          xini: 'lhs',
          vini: 'lhs2011',
          boundary: 'default',
          topology: 'random',
          c1: 1.193147,
          c2: 1.193147,
          lambda: 1,
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
    @analysis_job = Analysis::Core.initialize_analysis_job(@analysis, @analysis_job_id, @options)

    # reload the object (which is required) because the subdocuments (jobs) may have changed
    @analysis.reload

    # create an instance for R
    @r = Rserve::Simpler.new
    Rails.logger.info 'Setting up R for PSO Run'
    @r.converse("setwd('#{APP_CONFIG['sim_root_path']}')")

    # TODO: deal better with random seeds
    @r.converse "set.seed(#{@analysis.problem['random_seed']})"
    # R libraries needed for this algorithm
    @r.converse 'library(rjson)'
    @r.converse 'library(NRELpso)'

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = ComputeNode.where(node_type: 'server').first.ip_address
    Rails.logger.info("Master ip: #{master_ip}")
    Rails.logger.info('Starting PSO Run')

    # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
    # that the run flag is true.
    # Initialize some variables that are in the rescue/ensure blocks
    cluster = nil
    begin
      # TODO: preflight check -- need to catch this in the analysis module
      if @analysis.problem['algorithm']['maxit'].nil? || @analysis.problem['algorithm']['maxit'] == 0
        fail 'Number of max iterations was not set or equal to zero (must be 1 or greater)'
      end

      # TODO: add test for not "minkowski", "maximum", "euclidean", "binary", "manhattan"
      # if @analysis.problem['algorithm']['normtype'] != "minkowski", "maximum", "euclidean", "binary", "manhattan"
      #  raise "P Norm must be non-negative"
      # end
      unless %w(spso2007 spso2011 ipso fips wfips).include?(@analysis.problem['algorithm']['method'])
        fail 'unknown method type'
      end

      unless %w(lhs random).include?(@analysis.problem['algorithm']['xini'])
        fail 'unknown Xini type'
      end

      unless %w(zero lhs2011 random2011 lhs2007 random2007 default).include?(@analysis.problem['algorithm']['vini'])
        fail 'unknown Vini type'
      end

      unless %w(invisible damping reflecting absorbing2007 absorbing2007 default).include?(@analysis.problem['algorithm']['boundary'])
        fail 'unknown Boundary type'
      end

      unless %w(gbest lbest vonneumann random).include?(@analysis.problem['algorithm']['topology'])
        fail 'unknown Topology type'
      end

      if @analysis.problem['algorithm']['ppower'] <= 0
        fail 'P Norm must be non-negative'
      end

      @analysis.exit_on_guideline14 = @analysis.problem['algorithm']['exit_on_guideline14'] == 1 ? true : false

      @analysis.problem['algorithm']['objective_functions'] = [] unless @analysis.problem['algorithm']['objective_functions']

      @analysis.save!
      Rails.logger.info("exit_on_guideline14: #{@analysis.exit_on_guideline14}")

      # check to make sure there are objective functions
      if @analysis.output_variables.count { |v| v['objective_function'] == true } == 0
        fail 'No objective functions defined'
      end

      # find the total number of objective functions
      if @analysis.output_variables.count { |v| v['objective_function'] == true } != @analysis.problem['algorithm']['objective_functions'].size
        fail 'Number of objective functions must equal between the output_variables and the problem definition'
      end

      pivot_array = Variable.pivot_array(@analysis.id)
      selected_variables = Variable.variables(@analysis.id)
      Rails.logger.info "Found #{selected_variables.count} variables to perturb"

      # discretize the variables using the LHS sampling method
      @r.converse("print('starting lhs to discretize the variables')")
      Rails.logger.info 'starting lhs to discretize the variables'

      lhs = Analysis::R::Lhs.new(@r)
      samples, var_types, mins_maxes, var_names = lhs.sample_all_variables(selected_variables, 3)

      if var_names.empty? || var_names.size < 1
        Rails.logger.info 'No variables were passed into the options, therefore exit'
        fail "Must have at least one variable to run algorithm.  Found #{var_names.size} variables"
      end

      unless var_types.all? { |t| t.downcase == 'continuous' }
        Rails.logger.info 'Must have all continous variables to run algorithm, therefore exit'
        fail "Must have all continous variables to run algorithm.  Found #{var_types}"
      end

      Rails.logger.info "mins_maxes: #{mins_maxes}"
      Rails.logger.info "var_names: #{var_names}"

      # Result of the parameter space will be column vectors of each variable
      # Rails.logger.info "Samples are #{samples}"

      # Start up the cluster and perform the analysis
      cluster = Analysis::R::Cluster.new(@r, @analysis.id)
      unless cluster.configure(master_ip)
        fail 'could not configure R cluster'
      end

      # Initialize each worker node
      worker_ips = ComputeNode.worker_ips
      Rails.logger.info "Worker node ips #{worker_ips}"

      Rails.logger.info 'Running initialize worker scripts'
      unless cluster.initialize_workers(worker_ips, @analysis.id)
        fail 'could not run initialize worker scripts'
      end

      worker_ips = ComputeNode.worker_ips
      Rails.logger.info "Found the following good ips #{worker_ips}"

      if cluster.start(worker_ips)
        Rails.logger.info "Cluster Started flag is #{cluster.started}"
        # maxit is the max number of iterations to calculate

        # convert to float because the value is normally an integer and rserve/rserve-simpler only handles maxint
        @analysis.problem['algorithm']['abstol'] = @analysis.problem['algorithm']['abstol'].to_f
        @analysis.problem['algorithm']['reltol'] = @analysis.problem['algorithm']['reltol'].to_f
        @r.command(master_ips: master_ip, ips: worker_ips[:worker_ips].uniq, vartypes: var_types, varnames: var_names,
                   varseps: mins_maxes[:eps], mins: mins_maxes[:min], maxes: mins_maxes[:max],
                   normtype: @analysis.problem['algorithm']['normtype'], ppower: @analysis.problem['algorithm']['ppower'],
                   objfun: @analysis.problem['algorithm']['objective_functions'],
                   npart: @analysis.problem['algorithm']['npart'],
                   maxfn: @analysis.problem['algorithm']['maxfn'],
                   abstol: @analysis.problem['algorithm']['abstol'],
                   reltol: @analysis.problem['algorithm']['reltol'],
                   maxit: @analysis.problem['algorithm']['maxit'],
                   c1: @analysis.problem['algorithm']['c1'],
                   c2: @analysis.problem['algorithm']['c2'],
                   lambda: @analysis.problem['algorithm']['lambda'],
                   xini: @analysis.problem['algorithm']['xini'],
                   vini: @analysis.problem['algorithm']['vini'],
                   boundary: @analysis.problem['algorithm']['boundary'],
                   topology: @analysis.problem['algorithm']['topology'],
                   method: @analysis.problem['algorithm']['method']) do
          %{
            clusterEvalQ(cl,library(RMongo))
            clusterEvalQ(cl,library(rjson))
            clusterEvalQ(cl,library(R.utils))

            objDim <- length(objfun)
            print(paste("objDim:",objDim))
            print(paste("normtype:",normtype))
            print(paste("ppower:",ppower))

            print(paste("min:",mins))
            print(paste("max:",maxes))

            clusterExport(cl,"objDim")
            clusterExport(cl,"normtype")
            clusterExport(cl,"ppower")

            print(paste("vartypes:",vartypes))
            print(paste("varnames:",varnames))

            varfile <- function(x){
              if (!file.exists("#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/varnames.json")){
               write.table(x, file="#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/varnames.json", quote=FALSE,row.names=FALSE,col.names=FALSE)
              }
            }

            clusterExport(cl,"varfile")
            clusterExport(cl,"varnames")
            clusterEvalQ(cl,varfile(varnames))

            #f(x) takes a UUID (x) and runs the datapoint
            f <- function(x){
              mongo <- mongoDbConnect("#{Analysis::Core.database_name}", host="#{master_ip}", port=27017)
              flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{run_flag:1}')
              if (flag["run_flag"] == "false" ){
                stop(options("show.error.messages"=FALSE),"run flag is not TRUE")
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
              force(x)
              ruby_command <- "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/bundle exec ruby"

              # convert the vector to comma separated values
              w = paste(x, collapse=",")
              y <- paste(ruby_command," #{APP_CONFIG['sim_root_path']}/#{@options[:create_data_point_filename]} -a #{@analysis.id} -v ",w, sep="")
              z <- system(y,intern=TRUE)
              j <- length(z)
              z

              # Call the simulate data point method
            if (as.character(z[j]) == "NA") {
          cat("UUID is NA \n");
              NAvalue <- 1.0e19
              return(NAvalue)
      } else {
          try(f(z[j]), silent = TRUE)

              data_point_directory <- paste("#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/data_point_",z[j],sep="")

              # save off the variables file (can be used later if number of vars gets too long)
              write.table(x, paste(data_point_directory,"/input_variables_from_r.data",sep=""),row.names = FALSE, col.names = FALSE)

              # read in the results from the objective function file
              object_file <- paste(data_point_directory,"/objectives.json",sep="")
             json <- NULL
            try(json <- fromJSON(file=object_file), silent=TRUE)

            if (is.null(json)) {
              obj <- 1.0e19
            } else {
              obj <- NULL
              objvalue <- NULL
              objtarget <- NULL
              sclfactor <- NULL

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
              }
              options(digits=8)
              options(scipen=-2)
              print(paste("Objective function results are:",objvalue))
              print(paste("Objective function targets are:",objtarget))
              print(paste("Objective function scaling factors are:",sclfactor))
              objvalue <- objvalue / sclfactor
              objtarget <- objtarget / sclfactor
              obj <- force(eval(dist(rbind(objvalue,objtarget),method=normtype,p=ppower)))
              print(paste("Objective function Norm:",obj))

                mongo <- mongoDbConnect("#{Analysis::Core.database_name}", host="#{master_ip}", port=27017)
           flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{exit_on_guideline14:1}')
           print(paste("exit_on_guideline14: ",flag))

      if (flag["exit_on_guideline14"] == "true" ){
        # read in the results from the objective function file
        guideline_file <- paste(data_point_directory,"/run/CalibrationReports/guideline.json",sep="")
        json <- NULL
        try(json <- fromJSON(file=guideline_file), silent=TRUE)
        if (is.null(json)) {
          print(paste("no guideline file: ",guideline_file))
        } else {
                    guideline <- json[[1]]
                    for (i in 2:length(json)) guideline <- cbind(guideline,json[[i]])
                    print(paste("guideline: ",guideline))
                    print(paste("isTRUE(guideline): ",isTRUE(guideline)))
                    print(paste("all(guideline): ",all(guideline)))
                    if (length(which(guideline)) == objDim){
                      #write final params to json file
                      varnames <- scan(file="#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/varnames.json" , what=character())
                      answer <- paste('{',paste('"',gsub(".","|",varnames, fixed=TRUE),'"',': ',x,sep='', collapse=','),'}',sep='')
                      write.table(answer, file="#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/best_result.json", quote=FALSE,row.names=FALSE,col.names=FALSE)
                      convergenceflag <- paste('{',paste('"',"exit_on_guideline14",'"',': ',"true",sep='', collapse=','),'}',sep='')
                      write(convergenceflag, file="#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/convergence_flag.json")
                      dbDisconnect(mongo)
                      stop(options("show.error.messages"=FALSE),"exit_on_guideline14")
                    }
                  }
      }
                dbDisconnect(mongo)
                }
              return(as.numeric(obj))
              }
         }

            clusterExport(cl,"g")

            varMin <- mins
            varMax <- maxes
            varMean <- (mins+maxes)/2.0

            print(paste("Lower Bounds set to:",varMin))
            print(paste("Upper Bounds set to:",varMax))
            print(paste("Initial iterate set to:",varMean))

            if (npart == 0) {npart <- NA}
            print(paste("Number of particles set to:",npart))
            print(paste("maxit:", maxit))
            print(paste("maxfn:", maxfn))
            print(paste("abstol:", abstol))
            print(paste("reltol:", reltol))
            print(paste("method:", method))
            print(paste("xini:", xini))
            if (vini == "default") {vini <- NULL}
            print(paste("vini:", vini))
            if (boundary == "default") {boundary <- NULL}
            print(paste("boundary:", boundary))
            if (topology == "vonneumann") {topology <- "vonNeumann"}
            print(paste("topology:", topology))
            print(paste("c1:", c1))
            print(paste("c2:", c2))
            print(paste("lambda:", lambda))

            results <- NULL
            try(
                 results <- NRELpso(cl=cl, fn=g, lower=varMin, upper=varMax, method=method, control=list(write2disk=FALSE, parallel="true", npart=npart, maxit=maxit, maxfn=maxfn, abstol=abstol, reltol=reltol, Xini.type=xini, Vini.type=vini, boundary.wall=boundary, topology=topology, c1=c1, c2=c2, lambda=lambda))
               )
               #print(paste("scp command:",scp))
               #print(paste("scp command:",scp2))
               #system(scp,intern=TRUE)
               #system(scp2,intern=TRUE)
              print(paste("ip workers:", ips))
              print(paste("ip master:", master_ips))
              ips2 <- ips[ips!=master_ips]
              print(paste("non server ips:", ips2))
              num_uniq_workers <- length(ips2)
              whoami <- system('whoami', intern = TRUE)
              for (i in 1:num_uniq_workers){
                scp <- paste('scp ',whoami,'@',ips2[i],':#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/best_result.json #{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/', sep="")
                print(paste("scp command:",scp))
                system(scp,intern=TRUE)
                scp2 <- paste('scp ',whoami,'@',ips2[i],':#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/convergence_flag.json #{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/', sep="")
                print(paste("scp2 command:",scp2))
                system(scp2,intern=TRUE)
              }

            Rlog <- readLines('/var/www/rails/openstudio/log/Rserve.log')
            # Rlog[grep('vartypes:',Rlog)]
            # Rlog[grep('varnames:',Rlog)]
            # Rlog[grep('<=',Rlog)]
            # print(paste("popsize:",results$pop.size))
            # print(paste("peakgeneration:",results$peakgeneration))
            # print(paste("generations:",results$generations))
            # print(paste("gradients:",results$gradients))
             print(paste("par:",results$par))
             print(paste("value:",results$value))
             print(paste("counts:",results$counts))
             print(paste("convergence:",results$convergence))
             print(paste("message:",results$message))
             flush.console()
            save(results, file="#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/results.R")
            if (!file.exists("#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/best_result.json") && !is.null(results$par)) {
              #write final params to json file
              answer <- paste('{',paste('"',gsub(".","|",varnames, fixed=TRUE),'"',': ',results$par,sep='', collapse=','),'}',sep='')
              write.table(answer, file="#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/best_result.json", quote=FALSE,row.names=FALSE,col.names=FALSE)
              #convergenceflag <- toJSON(results$peakgeneration)
              convergenceflag <- paste('{',paste('"',"exit_on_guideline14",'"',': ',"false",sep='', collapse=','),'}',sep='')
              write(convergenceflag, file="#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/convergence_flag.json")
            }
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
      @analysis_job.status = 'completed'
      @analysis_job.save!
      @analysis.reload
      @analysis.save!
    ensure
      # ensure that the cluster is stopped
      cluster.stop if cluster

      Rails.logger.info 'Running finalize worker scripts'
      unless cluster.finalize_workers(worker_ips, @analysis.id)
        fail 'could not run finalize worker scripts'
      end

      # Post process the results and jam into the database
      best_result_json = "#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/best_result.json"
      if File.exist? best_result_json
        begin
          Rails.logger.info('read best result json')
          temp2 = File.read(best_result_json)
          temp = JSON.parse(temp2, symbolize_names: true)
          Rails.logger.info("temp: #{temp}")
          @analysis.results[@options[:analysis_type]]['best_result'] = temp
          @analysis.save!
          Rails.logger.info("analysis: #{@analysis.results}")
        rescue => e
          Rails.logger.error 'Could not save post processed results for bestresult.json into the database'
        end
      end

      # Post process the results and jam into the database
      converge_flag_json = "#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/convergence_flag.json"
      if File.exist? converge_flag_json
        begin
          Rails.logger.info('read converge_flag.json')
          temp2 = File.read(converge_flag_json)
          temp = JSON.parse(temp2, symbolize_names: true)
          Rails.logger.info("temp: #{temp}")
          @analysis.results[@options[:analysis_type]]['convergence_flag'] = temp
          @analysis.save!
          Rails.logger.info("analysis: #{@analysis.results}")
        rescue => e
          Rails.logger.error 'Could not save post processed results for converge_flag.json into the database'
        end
      end

      # Do one last check if there are any data points that were not downloaded
      Rails.logger.info('Trying to download any remaining files from worker nodes')
      @analysis.finalize_data_points

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
