class Analysis::NSGA2NREL
  def initialize(analysis_id, options = {})
    #TODO create create_data_point.rb
    defaults = {
        skip_init: false,
        vars: [],
        vartypes: [],
        gen: 20,
        run_data_point_filename: "run_openstudio_workflow.rb",
        create_data_point: "create_data_point.rb"
    }
    @options = defaults.merge(options)
    @analysis_id = analysis_id
  end

  # Perform is the main method that is run in the background.  At the moment if this method crashes
  # it will be logged as a failed delayed_job and will fail after max_attempts.
  def perform
    # add into delayed job
    require 'rserve/simpler'
    require 'uuid'
    require 'childprocess'

    @analysis = Analysis.find(@analysis_id)

    #create an instance for R
    @r = Rserve::Simpler.new
    Rails.logger.info "Setting up R for Batch Run"
    @r.converse('setwd("/mnt/openstudio")')
    @r.converse "library(snow)"
    @r.converse "library(snowfall)"
    @r.converse "library(RMongo)"
    @r.converse "library(R.methodsS3)"
    @r.converse "library(R.oo)"
    @r.converse "library(R.utils)"
    @r.converse "library(mco)"
    @r.converse "library(nsga2NREL)"

    @analysis.status = 'started'
    @analysis.run_flag = true
    @analysis.save!

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = ComputeNode.where(node_type: 'server').first.ip_address
    Rails.logger.info("Master ip: #{master_ip}")
    Rails.logger.info("Starting Batch Run")

    # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
    # that the run flag is true.

    if @options[:vars].empty?
      Rails.logger.info "No variables were passed into the options, therefore exit"
      #TODO exit run      
    end

    @r.command() do
      %Q{
        ip <- "#{master_ip}"
        results <- NULL
        print(ip)
        print(getwd())
        if (file.exists('/mnt/openstudio/rtimeout')) {
          file.remove('/mnt/openstudio/rtimeout')
        }
        #test the query of getting the run_flag
        mongo <- mongoDbConnect("os_dev", host=ip, port=27017)
        flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{run_flag:1}')

        print(flag["run_flag"])
        if (flag["run_flag"] == "true"  ){
          print("flag is set to true!")
        }        
        dbDisconnect(mongo)
      }
    end

    # Before kicking off the Analysis, make sure to setup the downloading of the files child process
    process = ChildProcess.build("/usr/local/rbenv/shims/bundle", "exec", "rake", "datapoints:download[#{@analysis.id}]", "RAILS_ENV=#{Rails.env}")
    #log_file = File.join(Rails.root,"log/download.log")
    #Rails.logger.info("Log file is: #{log_file}")
    process.io.inherit!
    #process.io.stdout = process.io.stderr = File.open(log_file,'a+')
    process.cwd = Rails.root # set the child's working directory where the bundler will execute
    Rails.logger.info("Starting Child Process")
    process.start

    good_ips = ComputeNode.where(valid: true) # TODO: make this a scope
    @analysis.analysis_output = []
    @analysis.analysis_output << "good_ips = #{good_ips.to_hash}"
    Rails.logger.info("Found the following good ips #{good_ips.to_hash}")

    @r.command(ips: good_ips.to_hash.to_dataframe) do
      %Q{
        print(ips)
        if (nrow(ips) == 0) {
          stop(options("show.error.messages"="No Worker Nodes")," No Worker Nodes")
        }
        uniqueips <- unique(ips)
        numunique <- nrow(uniqueips) * 180
        print("max timeout is:")
        print(numunique)
        timeflag <<- TRUE;
        res <- NULL;
	      starttime <- Sys.time()
	      tryCatch({
           res <- evalWithTimeout({
           cl <- makeSOCKcluster(ips[,1])
            }, timeout=numunique);
            }, TimeoutException=function(ex) {
              cat("#{@analysis.id} Timeout\n");
              timeflag <<- FALSE;
              file.create('rtimeout') 
              stop
          })
        endtime <- Sys.time()
	      timetaken <- endtime - starttime
        print("R cluster startup time:")
        print(timetaken)
        }
    end

    timeflag = @r.converse("timeflag")

    Rails.logger.info ("Time flag was set to #{timeflag}")
    if timeflag
      #gen is the number of generations to calculate
      #varNo is the number of variables (ncol(vars))
      #popSize is the number of sample points in the variable (nrow(vars))
      @r.command(vars.to_dataframe, vartypes, gen) do
        %Q{
          clusterEvalQ(cl,library(RMongo))
          
          #f(x) takes a UUID (x) and runs the datapoint
          f <- function(x){
            mongo <- mongoDbConnect("os_dev", host="#{master_ip}", port=27017)
            flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{run_flag:1}')
            if (flag["run_flag"] == "false" ){
              stop(options("show.error.messages"="Not TRUE"),"run flag is not TRUE")
            }
            dbDisconnect(mongo)

            ruby_command <- "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/"
            print("#{@analysis.use_shm}")
            if ("#{@analysis.use_shm}" == "true"){
              y <- paste(ruby_command," /mnt/openstudio/simulate_data_point.rb -a #{@analysis.id} -u ",x," -x #{@options[:run_data_point_filename]} -r AWS --run-shm",sep="")
            } else {
              y <- paste(ruby_command," /mnt/openstudio/simulate_data_point.rb -a #{@analysis.id} -u ",x," -x #{@options[:run_data_point_filename]} -r AWS",sep="")
            }
            z <- system(y,intern=TRUE)
            j <- length(z)
            z
          }
          clusterExport(cl,"f")
          
          #g(x) such that x is vector of variable values, 
          #           create a data_point from the vector of variable values x
          #           create a UUID for that data_point and put in database
          #           call f(u) where u is UUID of data_point
	  g <- function(x){
	    ruby_command <- "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/"
	    print("#{@analysis.use_shm}")
	    if ("#{@analysis.use_shm}" == "true"){
	      y <- paste(ruby_command," /mnt/openstudio/#{@options[:create_data_point]} -a #{@analysis.id} -u ",x," --run-shm",sep="")
	    } else {
	      y <- paste(ruby_command," /mnt/openstudio/#{@options[:create_data_point]} -a #{@analysis.id} -u ",x,sep="")
	    }
	    z <- system(y,intern=TRUE)
	    j <- length(z)
	    z
	    f(z[j])
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
          results <- nsga2NREL(cl=cl,fn=g,objdim=2,variables=vars[],vartype=vartypes,generations=gen,mprob=0.8)
          #results <- sfLapply(vars[,1], f)

          stopCluster(cl)
        }
      end
    else
      # Log off some information why it didnt' start
    end
    @analysis.analysis_output << @r.converse("results")

    # Kill the downloading of data files process
    process.stop

    # Do one last check if there are any data points that were not downloaded
    Rails.logger.info("Trying to download any remaining files from worker nodes")
    @analysis.finalize_data_points

    # Only set this data if the anlaysis was NOT called from another anlaysis

    if !@options[:skip_init]
      @analysis.end_time = Time.now
      @analysis.status = 'completed'
      @analysis.save!
    end
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    return 1
  end
end

