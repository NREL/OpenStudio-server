# This class allows you to submit a large number of analysis that have simulations ready to run. Ideally use this
# for differing workflows and single_runs. This is not an ideal implementation and should be an actual queue
class Analysis::BatchRunAnalyses
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
    Rails.logger.info 'Setting up R for Batch Run Analysis'
    @r.converse('setwd("/mnt/openstudio")')

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = ComputeNode.where(node_type: 'server').first.ip_address
    Rails.logger.info('Starting Batch Run Analysis')

    # Find all the data_points across all analyses
    dp_map = { analysis_id: [], data_point_id: [] }
    dps = DataPoint.where(status: 'na', download_status: 'na').only(:status, :download_status, :uuid, :analysis)
    dps.each do |dp|
      Rails.logger.info "Adding in #{dp.uuid}"
      # TODO: uncomment this in production
      dp.status = 'queued'
      dp.save!

      dp_map[:analysis_id] << dp.analysis.id
      dp_map[:data_point_id] << dp.uuid
    end

    # Gather all the analyses as objects of the datapoints
    Rails.logger.info("Found #{dp_map[:data_point_id].size} across all analyses to run")
    analyses = dp_map[:analysis_id].map { |id| Analysis.find(id) }.uniq

    # Initialize some variables that are in the rescue/ensure blocks
    cluster = nil
    process = nil
    begin
      # Start up the cluster and perform the analysis
      cluster = Analysis::R::Cluster.new(@r, @analysis.id)
      unless cluster.configure(master_ip)
        fail 'could not configure R cluster'
      end

      # Initialize each worker node
      worker_ips = ComputeNode.worker_ips
      Rails.logger.info "Worker node ips #{worker_ips}"

      # copy the files to the worker nodes here
      Rails.logger.info "Initializing the analyses of the data points for #{analyses.map(&:id)}"
      analyses.each do |analysis|
        Rails.logger.info 'Running initialize worker scripts'
        unless cluster.initialize_workers(worker_ips, analysis.id)
          fail 'could not run initialize worker scripts'
        end
      end

      # Before kicking off the Analysis, make sure to setup the downloading of the files child process
      process = Analysis::Core::BackgroundTasks.start_child_processes

      if cluster.start(worker_ips)
        Rails.logger.info "Cluster Started flag is #{cluster.started}"
        @r.command(dps: dp_map.to_dataframe) do
          %{
            print("Starting main portion of Batch Run Analysis")
            print(dps)
            clusterEvalQ(cl,library(RMongo))

            f <- function(dp_index){
              print(paste("Analysis ID:", dps$analysis_id[dp_index], "Data Point ID:", dps$data_point_id[dp_index]))
              mongo <- mongoDbConnect("#{Analysis::Core.database_name}", host="#{master_ip}", port=27017)
              flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{run_flag:1}')
              if (flag["run_flag"] == "false" ){
                stop(options("show.error.messages"="Not TRUE"),"run flag is not TRUE")
              }
              dbDisconnect(mongo)

              ruby_command <- "cd /mnt/openstudio && #{APP_CONFIG['ruby_bin_dir']}/bundle exec ruby"
              y <- paste(ruby_command," /mnt/openstudio/simulate_data_point.rb -a ",dps$analysis_id[dp_index]," -u ",dps$data_point_id[dp_index]," -x #{@options[:run_data_point_filename]}",sep="")
              print(paste("Batch Run Analysis Command: ",y))
              z <- system(y,intern=TRUE)
              j <- length(z)
              z
            }
            clusterExport(cl,"f")

            if (nrow(dps) == 1) {
              print("not sure what to do with only one data point so adding an NA")
              dps <- rbind(dps, c(NA,NA))
            }
            if (nrow(dps) == 0) {
              print("not sure what to do with no data point so adding two NAs")
              dps <- rbind(dps, c(NA,NA))
              dps <- rbind(dps, c(NA,NA))
            }

            # Explort the datapoints dataframe so that the index into the array can be looked up on all the worker nodes
            clusterExport(cl, "dps")

            print(paste("Number of data points:",nrow(dps)))

            results <- clusterApplyLB(cl, seq(nrow(dps)), f)
            # For verbose logging you can print the results using `print(results)`
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
      cluster.stop if cluster

      # Kill the downloading of data files process
      Rails.logger.info('Ensure block of analysis cleaning up any remaining processes')
      process.stop if process
    end

    analyses.each do |analysis|
      Rails.logger.info 'Running finalize worker scripts'
      unless cluster.finalize_workers(worker_ips, analysis.id)
        fail 'could not run finalize worker scripts'
      end
    end

    # Do one last check if there are any data points that were not downloaded
    begin
      # in large analyses it appears that this is timing out or just not running to completion.
      analyses.each do |analysis|
        Rails.logger.info('Trying to download any remaining files from worker nodes')
        analysis.finalize_data_points
      end

      # go through and mark any data points that are still queued as NA, this will reset the data points if the
      # analysis bombs out
      dps = DataPoint.where(:id.in => dp_map[:data_point_id]).and(status: 'queued')
      dps.each do |dp|
        dp.status = 'na'
        dp.save!
      end
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
