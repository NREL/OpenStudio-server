class Analysis::BatchRun < Struct.new(:options)
  def initialize(analysis_id, data_points)
    @analysis_id = analysis_id
    @data_points = data_points
  end

  def get_worker_ips

  end

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

    @analysis.status = 'started'
    @analysis.run_flag = true
    @analysis.save!

    # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
    # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

    # get the master ip address
    master_ip = MasterNode.first.ip_address
    Rails.logger.info("master ip: #{master_ip}")

    # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
    # that the run flag is true.
    @r.command() do
      %Q{
        ip <- "#{master_ip}"
        print(ip)
        print(getwd())

        #test the query of getting the run_flag
        mongo <- mongoDbConnect("os_dev", host=ip, port=27017)
        flag <- dbGetQuery(mongo, "analyses", '{_id:"#{@analysis.id}"}')
        #print(flag)

        print(flag["run_flag"])
        if (flag["run_flag"] == "true"  ){
          print("flag is set to true!")
        }
      }
    end

    # Before kicking off the Analysis, make sure to setup the downloading of the files child process
    process = ChildProcess.build("/usr/local/rbenv/shims/bundle", "exec", "rake", "datapoints:download[#{@analysis.id}]")
    process.io.stdout = process.io.stderr = Tempfile.new("download-output.log")
    process.cwd = Rails.root # set the child's working directory where the bundler will execute
    process.start
    
    good_ips = WorkerNode.where(valid:true)
    #@r.command(ips: WorkerNode.to_hash.to_dataframe, dps: @data_points.to_dataframe) do
    @r.command(ips: good_ips.to_hash.to_dataframe, dps: @data_points.to_dataframe) do
      %Q{
        print(ips)
        if (nrow(ips) == 0) {
          stop(options("show.error.messages"="No Worker Nodes")," No Worker Nodes")
        }
        sfInit(parallel=TRUE, type="SOCK", socketHosts=ips[,1])
        sfLibrary(RMongo)

        f <- function(x){
          mongo <- mongoDbConnect("os_dev", host="#{master_ip}", port=27017)
          flag <- dbGetQuery(mongo, "analyses", '{_id:"#{@analysis.id}"}')
          if (flag["run_flag"] == "false" ){
            stop(options("show.error.messages"="TRUE"),"run flag is not TRUE")
          }
          dbDisconnect(mongo)

          y <- paste("/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /mnt/openstudio/SimulateDataPoint.rb -u ",x," -d /mnt/openstudio/analysis/data_point_",x," -r AWS > /mnt/openstudio/",x,".log",sep="")
          #y <- "sleep 1; echo hello"
            z <- system(y,intern=TRUE)
          j <- length(z)
          z
        }
        sfExport("f")

        if (nrow(dps) == 1) {
          print("not sure what to do with only one datapoint so adding an NA")
          dps <- rbind(dps, c(NA))
        }

        print(dps)

        results <- sfLapply(dps[,1], f)

        sfStop()
      }
    end

    @analysis.log_r = @r.converse("results")

    # Kill the downloading of data files process
    process.stop

    # Do one last check if there are any data points that were not downloaded
    @analysis.download_data_from_workers

    @analysis.status = 'completed'
    @analysis.save!
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    return 1
  end
end

