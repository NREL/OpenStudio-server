class Analysis::BatchRun
  def initialize(analysis_id, options = {})
    defaults = {:skip_init => false, :simulate_data_point_filename => "simulate_data_point.rb"}
    @options = defaults.merge(options)

    @analysis_id = analysis_id
  end

  # Perform is the main method that is run in the background.  At the moment if this method crashes
  # it will be logged as a failed delayed_job and will fail after max_attempts.
  def perform
    @analysis = Analysis.find(@analysis_id)

    if @options[:skip_init]
      @analysis.status = 'started'
      @analysis.end_time = nil
      @analysis.save!
    end

    if @options[:data_points] && !@options[:data_points].empty?
      # add into delayed job
      require 'rserve/simpler'
      require 'uuid'
      require 'childprocess'

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

      # Set this if not defined in the JSON
      Rails.logger.info "F.rb was #{@options[:simulate_data_point_filename]}"
      Rails.logger.info "F.rb is #{@options[:simulate_data_point_filename]}"
      @analysis.run_flag = true # this has to be set or RMongo will fail
      @analysis.save!


      # At this point we should really setup the JSON that can be sent to the worker nodes with everything it needs
      # This would allow us to easily replace the queuing system with rabbit or any other json based versions.

      # get the master ip address
      master_ip = MasterNode.first.ip_address
      Rails.logger.info("Master ip: #{master_ip}")
      Rails.logger.info("Starting Batch Run")

      # Quick preflight check that R, MongoDB, and Rails are working as expected. Checks to make sure
      # that the run flag is true.


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
      #process.start

      good_ips = WorkerNode.where(valid: true) # TODO: make this a scope
      @analysis.analysis_output = []
      @analysis.analysis_output << "good_ips = #{good_ips.to_json}"

      @r.command(ips: good_ips.to_hash.to_dataframe) do
        %Q{
          print(ips)
          if (nrow(ips) == 0) {
            stop(options("show.error.messages"="No Worker Nodes")," No Worker Nodes")
          }
          sfSetMaxCPUs(nrow(ips))
          timeflag <<- TRUE;
          res <- NULL;
          tryCatch({
            res <- evalWithTimeout({
              sfInit(parallel=TRUE, type="SOCK", socketHosts=ips[,1], slaveOutfile="/mnt/openstudio/rails-models/snowfall.log");
              }, timeout=60);
            }, TimeoutException=function(ex) {
              cat("#{@analysis.id} Timeout\n");
              timeflag <<- FALSE;
              file.create('rtimeout')
              stop
          })
        }
      end

      timeflag = @r.converse("timeflag")

      Rails.logger.info ("Time flag was set to #{timeflag}")
      if timeflag
        @r.command(ips: good_ips.to_hash.to_dataframe, dps: {:data_points => @options[:data_points]}.to_dataframe) do
          %Q{
            print("Size of cluster is:")
            print(sfCpus())

            sfLibrary(RMongo)

            f <- function(x){
              mongo <- mongoDbConnect("os_dev", host="#{master_ip}", port=27017)
              flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis.id}"}', '{run_flag:1}')
              if (flag["run_flag"] == "false" ){
                stop(options("show.error.messages"="Not TRUE"),"run flag is not TRUE")
              }
              dbDisconnect(mongo)

              print("#{@analysis.use_shm}")
              if ("#{@analysis.use_shm}" == "true"){
                y <- paste("/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /mnt/openstudio/#{@options[:simulate_data_point_filename]} -u ",x," -r AWS --run-shm",sep="")
              } else {
                y <- paste("/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /mnt/openstudio/#{@options[:simulate_data_point_filename]} -u ",x," -r AWS",sep="")
              }
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
      else
        # Log off some information why it didnt' start
      end
      @analysis.analysis_output << @r.converse("results")

      # Kill the downloading of data files process
      #process.stop

      # This can cause an issue when this method is called from another analysis becuase of permission of the file.
      #   Either 1) we need to have delayed jobs run as a user that has the permissions
      #          2) remove a partially downloaded
      #          3) set permissions
      Rails.logger.info("Trying to download any remaining files from worker nodes")
      @analysis.finalize_data_points # not sure where this should go right now...

    else
      Rails.logger.info("No datapoints to run in #{__FILE__}")
    end


    # This is to handle the sequential search case. But this should really be a separate analysis for each iteration
    if @options[:skip_init]
      # Do one last check if there are any data points that were not downloaded
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


