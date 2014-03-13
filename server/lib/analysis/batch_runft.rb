class Analysis::BatchRunft
  def initialize(analysis_id, options = {})
    defaults = {
        skip_init: false,
        data_points: [],
        run_data_point_filename: "run_openstudio.rb",
        problem: {}
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

    # save all the changes into the database and reload the object (which is required)
    @analysis.save!
    @analysis.reload


    #create an instance for R
    @r = Rserve::Simpler.new
    Rails.logger.info "Setting up R for Batch Run"
    @r.converse('setwd("/mnt/openstudio")')

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = ComputeNode.where(node_type: 'server').first.ip_address
    Rails.logger.info("Master ip: #{master_ip}")
    Rails.logger.info("Starting Batch Run")

    # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
    # that the run flag is true.

    if @options[:data_points].empty?
      Rails.logger.info "No datapoints were passed into the options, therefore checking which datapoints to run"
      @analysis.data_points.where(status: 'na', download_status: 'na').only(:status, :download_status, :uuid).each do |dp|
        Rails.logger.info "Adding in #{dp.uuid}"
        dp.status = 'queued'
        dp.save!
        @options[:data_points] << dp.uuid
      end
    end

    # Initialize some variables that are in the rescue/ensure blocks
    cluster_started = false
    cluster = nil
    process = nil
    begin
      # Start up the cluster and perform the analysis
      cluster = Analysis::R::Clusterft.new(@r, @analysis.id)
      if !cluster.configure(master_ip)
        raise "could not configure R cluster"
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

      worker_ips = ComputeNode.worker_ips
      Rails.logger.info("Found the following good ips #{worker_ips}")

      cluster_started = cluster.start(worker_ips)
      Rails.logger.info ("Time flag was set to #{cluster_started}")

      #todo: move os_dev to a variable based on environment
      if cluster_started
        @r.command(dps: {data_points: @options[:data_points]}.to_dataframe) do
          %Q{
            clusterEvalQ(cl,library(RMongo)) 
  
            f <- function(x){
              mongo <- mongoDbConnect("os_dev", host="#{master_ip}", port=27017)
              flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{run_flag:1}')
              if (flag["run_flag"] == "false" ){
                stop(options("show.error.messages"="Not TRUE"),"run flag is not TRUE")
              }
              dbDisconnect(mongo)
  
              ruby_command <- "/usr/local/rbenv/shims/ruby"
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
  
            if (nrow(dps) == 1) {
              print("not sure what to do with only one datapoint so adding an NA")
              dps <- rbind(dps, c(NA))
            }
            if (nrow(dps) == 0) {
              print("not sure what to do with no datapoint so adding an NA")
              dps <- rbind(dps, c(NA))
              dps <- rbind(dps, c(NA))
            }
  
            print(paste("number of datapoints is:",nrow(dps)))
            results <- clusterApplyFT(cl, dps[,1], f, initfun="f", mngtfiles=c("/mnt/openstudio/.clustersize","/mnt/openstudio/.proc","/mnt/openstudio/.proc_fail"), ipFile="/mnt/openstudio/.newIPs", resizeFile="/mnt/openstudio/.resizeFile", ft_verbose=TRUE, outfile="/mnt/openstudio/snow.log")
            #results <- parLapply(cl, dps[,1], f)
          }
        end
      else
        raise "could not start the cluster (most likely timed out)"
      end
    rescue Exception => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      puts log_message
      @analysis.status_message = log_message
      @analysis.save!
    ensure
      # ensure that the cluster is stopped
      cluster.stop if cluster && cluster_started

      # Kill the downloading of data files process
      Rails.logger.info("Ensure block of analysis cleaning up any remaining processes")
      process.stop if process

      # Do one last check if there are any data points that were not downloaded
      Rails.logger.info("Trying to download any remaining files from worker nodes")
      @analysis.finalize_data_points

      # Only set this data if the anlaysis was NOT called from another anlaysis

      if !@options[:skip_init]
        @analysis.end_time = Time.now
        @analysis.status = 'completed'
      end

      @analysis.save!
    end
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    return 1
  end
end

