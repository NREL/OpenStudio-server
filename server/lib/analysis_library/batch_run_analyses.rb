# *******************************************************************************
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
# *******************************************************************************

# TODO: Fix this for new queue

# This class allows you to submit a large number of analysis that have simulations ready to run. Ideally use this
# for differing workflows and single_runs. This is not an ideal implementation and should be an actual queue
class AnalysisLibrary::BatchRunAnalyses < AnalysisLibrary::Base
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
    @analysis_job = AnalysisLibrary::Core.initialize_analysis_job(@analysis, @analysis_job_id, @options)

    # reload the object (which is required) because the subdocuments (jobs) may have changed
    @analysis.reload

    # create an instance for R
    @r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                 APP_CONFIG['rserve_port'])
    logger.info 'Setting up R for Batch Run Analysis'
    @r.converse("setwd('#{APP_CONFIG['sim_root_path']}')")

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = ComputeNode.where(node_type: 'server').first.ip_address
    logger.info('Starting Batch Run Analysis')

    # Find all the data_points across all analyses
    dp_map = { analysis_id: [], data_point_id: [] }
    dps = DataPoint.where(status: 'na').only(:status, :uuid, :analysis)
    dps.each do |dp|
      dp.status = 'queued'
      dp.save!

      dp_map[:analysis_id] << dp.analysis.id
      dp_map[:data_point_id] << dp.uuid
    end

    # Gather all the analyses as objects of the datapoints
    logger.info("Found #{dp_map[:data_point_id].size} across all analyses to run")
    analyses = dp_map[:analysis_id].map { |id| Analysis.find(id) }.uniq

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

      # copy the files to the worker nodes here
      logger.info "Initializing the analyses of the datapoints for #{analyses.map(&:id)}"
      analyses.each do |analysis|
        logger.info 'Running initialize worker scripts'
        unless cluster.initialize_workers(worker_ips, analysis.id)
          raise 'could not run initialize worker scripts'
        end
      end

      if cluster.start(worker_ips)
        logger.info "Cluster Started flag is #{cluster.started}"
        @r.command(dps: dp_map.to_dataframe) do
          %{
            print("Starting main portion of Batch Run Analysis")
            print(dps)
            # TODO: remove rmongo
            clusterEvalQ(cl,library(RMongo))

            f <- function(dp_index){
              print(paste("Analysis ID:", dps$analysis_id[dp_index], "Datapoint ID:", dps$data_point_id[dp_index]))
              mongo <- mongoDbConnect("#{AnalysisLibrary::Core.database_name}", host="#{master_ip}", port=27017)
              flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{run_flag:1}')
              if (flag["run_flag"] == "false" ){
                stop(options("show.error.messages"="Not TRUE"),"run flag is not TRUE")
              }
              dbDisconnect(mongo)

              ruby_command <- "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/bundle exec ruby"
              y <- paste(ruby_command," #{APP_CONFIG['sim_root_path']}/simulate_data_point.rb -a ",dps$analysis_id[dp_index]," -u ",dps$data_point_id[dp_index]," -x #{@options[:run_data_point_filename]}",sep="")
              print(paste("Batch Run Analysis Command: ",y))
              z <- system(y,intern=TRUE)
              j <- length(z)
              z
            }
            clusterExport(cl,"f")

            if (nrow(dps) == 1) {
              print("not sure what to do with only one datapoint so adding an NA")
              dps <- rbind(dps, c(NA,NA))
            }
            if (nrow(dps) == 0) {
              print("not sure what to do with no datapoint so adding two NAs")
              dps <- rbind(dps, c(NA,NA))
              dps <- rbind(dps, c(NA,NA))
            }

            # Explort the datapoints dataframe so that the index into the array can be looked up on all the worker nodes
            clusterExport(cl, "dps")

            print(paste("Number of datapoints:",nrow(dps)))

            results <- clusterApplyLB(cl, seq(nrow(dps)), f)
            # For verbose logging you can print the results using `print(results)`
          }
        end
      else
        raise 'could not start the cluster (most likely timed out)'
      end
    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      logger.error log_message
      @analysis.status_message = log_message
      @analysis.save!
    ensure
      # ensure that the cluster is stopped
      cluster.stop if cluster
    end

    analyses.each do |analysis|
      logger.info 'Running finalize worker scripts'
      unless cluster.finalize_workers(worker_ips, analysis.id)
        raise 'could not run finalize worker scripts'
      end
    end

    # Do one last check if there are any datapoints that were not downloaded
    begin
      # go through and mark any datapoints that are still queued as NA, this will reset the datapoints if the
      # analysis bombs out
      dps = DataPoint.where(:id.in => dp_map[:data_point_id]).and(status: 'queued')
      dps.each do |dp|
        dp.status = 'na'
        dp.save!
      end
    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      logger.error log_message
      @analysis.status_message += log_message
      @analysis.save!
    ensure
      # Only set this data if the analysis was NOT called from another analysis
      unless @options[:skip_init]
        require_relative "gather_results"
        zip_all_results(@analysis_id, 1)
        @analysis_job.end_time = Time.now
        @analysis_job.status = 'completed'
        @analysis_job.save!
        @analysis.reload
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
