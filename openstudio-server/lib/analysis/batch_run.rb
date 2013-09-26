class Analysis::BatchRun < Struct.new(:options)
  def initialize(analysis_id)
    @analysis_id = analysis_id
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

    # I think we can do this with mongoid at the moment... no reason to make this complicated until we have to send
    # the data to the worker nodes
    @r.command() do
      %Q{
        ip <- "#{master_ip}"
        print(ip)
        print(getwd())
        #mongo <- mongoDbConnect("openstudio_server_development", host=ip, port=27017)
        #output <- dbRemoveQuery(mongo,"control","{_id:1}")
        #if (output != "ok"){stop(options("show.error.messages"="TRUE"),"cannot remove control flag in Mongo")}
        #input <- dbInsertDocument(mongo,"control",'{"_id":1,"run":"TRUE"}')
        #if (input != "ok"){stop(options("show.error.messages"="TRUE"),"cannot insert control flag in Mongo")}
        #flag <- dbGetQuery(mongo,"control",'{"_id":1}')
        #if (flag["run"] != "TRUE" ){stop(options("show.error.messages"="TRUE"),"run flag is not TRUE")}
        #dbDisconnect(mongo)

        #test the query of getting the run_flag
        mongo <- mongoDbConnect("openstudio_server_development", host=ip, port=27017)
        flag <- dbGetQuery(mongo, "analyses", '{_id:"#{@analysis.id}"}')
        print(flag)

        print(flag["run_flag"])
        if (flag["run_flag"] == "true"  ){
          print("flag is set to true!")
        }
      }
    end

    # get the worker ips
    worker_ips_hash = {}
    worker_ips_hash[:worker_ips] = []

    WorkerNode.all.each do |wn|
      (1..wn.cores).each { |i| worker_ips_hash[:worker_ips] << wn.ip_address }
    end
    Rails.logger.info("worker ip hash: #{worker_ips_hash}")

    # update the status of all the datapoints and create a hash map
    data_points_hash = {}
    data_points_hash[:data_points] = []
    @analysis.data_points.all.each do |dp|
      dp.status = 'queued'
      dp.save!
      data_points_hash[:data_points] << dp.uuid
    end
    Rails.logger.info(data_points_hash)

    # Before kicking off the Analysis, make sure to setup the downloading of the files child process
    process = ChildProcess.build("/usr/local/rbenv/shims/bundle", "exec", "rake", "datapoints:download[#{@analysis.id}]")
    process.io.stdout = process.io.stderr = Tempfile.new("download-output.log")
    # set the child's working directory
    process.cwd = Rails.root

    Rails.logger.info(process.inspect)

    # start the process
    process.start

    @r.command(ips: worker_ips_hash.to_dataframe, dps: data_points_hash.to_dataframe) do
      %Q{
        sfInit(parallel=TRUE, type="SOCK", socketHosts=ips[,1])
        sfLibrary(RMongo)

        f <- function(x){
          mongo <- mongoDbConnect("openstudio_server_development", host="#{master_ip}", port=27017)
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

    #@analysis.r_log = @r.converse(messages)

    # check if there are any other datapoints that need downloaded?
    process.stop

    # Do one last check if there are any models to download
    @analysis.download_data_from_workers

    @analysis.status = 'completed'
    @analysis.save!
  end

  def max_attempts
    return 1
  end
end

