class Analysis::BatchRunft
  include Analysis::Core

  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = {
      skip_init: false,
      data_points: [],
      run_data_point_filename: 'run_openstudio.rb',
      problem: {}
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
    Rails.logger.info 'Setting up R for Batch Run'
    @r.converse('setwd("/mnt/openstudio")')

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = ComputeNode.where(node_type: 'server').first.ip_address
    Rails.logger.info("Master ip: #{master_ip}")
    Rails.logger.info('Starting Batch Run')

    # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
    # that the run flag is true.
    if @options[:data_points].empty?
      Rails.logger.info 'No data points were passed into the options, therefore checking which data points to run'
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

      # Before kicking off the Analysis, make sure to setup the downloading of the files child process
      process = Analysis::Core::BackgroundTasks.start_child_processes(@analysis.id)

      if cluster.start(worker_ips)
        cluster_started = true
        Rails.logger.info "Time flag was set to #{cluster_started}"
        @r.command(dps: { data_points: @options[:data_points] }.to_dataframe) do
          %{
            clusterEvalQ(cl,library(RMongo))

            f <- function(x){
              mongo <- mongoDbConnect("#{Analysis::Core.database_name}", host="#{master_ip}", port=27017)
              flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{run_flag:1}')
              if (flag["run_flag"] == "false" ){
                stop(options("show.error.messages"="Not TRUE"),"run flag is not TRUE")
              }
              dbDisconnect(mongo)

              ruby_command <- "cd /mnt/openstudio && #{RUBY_BIN_DIR}/bundle exec ruby"
              print(paste("Use dev/shm set to:","#{@analysis.use_shm}"))
              if ("#{@analysis.use_shm}" == "true"){
                y <- paste(ruby_command," /mnt/openstudio/simulate_data_point.rb -a #{@analysis.id} -u ",x," -x #{@options[:run_data_point_filename]} --run-shm",sep="")
              } else {
                y <- paste(ruby_command," /mnt/openstudio/simulate_data_point.rb -a #{@analysis.id} -u ",x," -x #{@options[:run_data_point_filename]}",sep="")
              }
              print(paste("Run command",y))
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
              print("not sure what to do with no datapoint so adding two NAs")
              dps <- rbind(dps, c(NA))
              dps <- rbind(dps, c(NA))
            }

            print(paste("Number of datapoints:",nrow(dps)))

            results <- clusterApplyFT(cl, dps[,1], f, initfun="f", mngtfiles=c("/mnt/openstudio/.clustersize","/mnt/openstudio/.proc","/mnt/openstudio/.proc_fail"), ipFile="/mnt/openstudio/.newIPs", resizeFile="/mnt/openstudio/.resizeFile", ft_verbose=TRUE, outfile="/mnt/openstudio/snow.log")
            # For verbose logging you can print the results using `print(results)`
          }
        end
      else
        fail 'could not start the cluster (most likely timed out)'
      end

      Rails.logger.info 'Running finalize worker scripts'
      unless cluster.finalize_workers(worker_ips, @analysis.id)
        fail 'could not run finalize worker scripts'
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
    end

    # Do one last check if there are any data points that were not downloaded
    begin
      # in large analyses it appears that this is timing out or just not running to completion.
      Rails.logger.info('Trying to download any remaining files from worker nodes')
      @analysis.finalize_data_points
    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      Rails.logger.error log_message
      @analysis.status_message += log_message
      @analysis.save!
    ensure
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
