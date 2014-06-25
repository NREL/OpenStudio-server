module Analysis::R
  class Cluster
    def initialize(r_session, analysis_id)
      @r = r_session
      @analysis_id = analysis_id

      # load the required libraries for cluster management
      @r.converse "print('Configuring R Cluster - Loading Libraries')"
      @r.converse 'library(snow)'
      @r.converse 'library(RMongo)'
      @r.converse 'library(R.utils)'

      # determine the database name based on the environment
      if Rails.env == 'development'
        @db = 'os_dev'
      elsif Rails.env == 'production'
        @db = 'os_prod'
      elsif Rails.env == 'test'
        @db = 'os_test'
      end
    end

    # configure the r session, returns true if the flag variable was readable (and true)
    def configure(master_ip)
      result = false
      @r.command do
        %Q{
            ip <- "#{master_ip}"
            results <- NULL
            print(paste("Master ip address is",ip))
            print(paste("Current working directory is",getwd()))
            if (file.exists('/mnt/openstudio/rtimeout')) {
              file.remove('/mnt/openstudio/rtimeout')
            }
            #test the query of getting the run_flag
            print(paste("Connecting to MongoDB: #{@db}"))
            mongo <- mongoDbConnect("#{@db}", host=ip, port=27017)
            flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis_id}"}', '{run_flag:1}')

            print(paste("Run flag:",flag['run_flag']))
            dbDisconnect(mongo)
          }
      end

      out = @r.converse "flag['run_flag'][,1]"
      result = out == 'true' ? true : false

      # note that if result is false it may be because the Rserve session wasn't running right, or the analysis
      # database record was not found

      result
    end

    # start the cluster.  Returns true if the cluster was started, false
    # if the cluster timed out or failed. The IP addresses are passed as a hash of an arrays a["ip"] = ["ip1", "ip2", ...]
    def start(ip_addresses)
      result = false
      @r.command(ips: ip_addresses.to_dataframe) do
        %Q{
        
	 checkForRemoteErrors <- function(val){
	      count <- 0
	      firstmsg <- NULL
	      for (v in val) {
		  if (inherits(v, "try-error")) {
		      count <- count + 1
		      if (count == 1) 
			  firstmsg <- v
		  }
	      }
	      if (count == 1) 
		  print(paste("one node produced an error: ", firstmsg))
	      else if (count > 1) 
		  print(paste(count, " nodes produced errors; first error: ", 
			      firstmsg))
	      val
	 }
 
          unlockBinding("checkForRemoteErrors", as.environment("package:snow"))
          assignInNamespace("checkForRemoteErrors",checkForRemoteErrors, ns="snow", envir=as.environment("package:snow"))
          assign("checkForRemoteErrors", checkForRemoteErrors, as.environment("package:snow"))
          lockBinding("checkForRemoteErrors", as.environment("package:snow"))        
        
        
          print("Starting cluster...")
          print(paste("Worker IPs:", ips))
          if (nrow(ips) == 0) {
            stop(options("show.error.messages"="No Worker Nodes")," No Worker Nodes")
          }
          uniqueips <- unique(ips)
          numunique <- nrow(uniqueips) * 180
          print(paste("max timeout is:",numunique))
          timeflag <<- TRUE;
          res <- NULL;
          starttime <- Sys.time()
          tryCatch({
             res <- evalWithTimeout({
             cl <- makeSOCKcluster(ips[,1], outfile="/tmp/snow.log")
              }, timeout=numunique);
              }, TimeoutException=function(ex) {
                cat("#{@analysis_id} Timeout\n");
                timeflag <<- FALSE;
                file.create('rtimeout')
                stop
            })
          endtime <- Sys.time()
          timetaken <- endtime - starttime
          print(paste("R cluster startup time:",timetaken))

          print(paste("whoami:",system('whoami', intern = TRUE)))
          print(paste("PATH:",Sys.getenv("PATH")))
          print(paste("RUBYLIB:",Sys.getenv("RUBYLIB")))
          print(paste("R_HOME:",Sys.getenv("R_HOME")))
          print(paste("R_ENVIRON:",Sys.getenv("R_ENVIRON")))
          print("Cluster started")
        }
      end
      result = @r.converse('timeflag')
    end

    def stop
      result = false
      @r.command do
        %Q{
            print("Stopping cluster...")
            stopCluster(cl)
            print("Cluster stopped")
          }
      end

      # todo: how to test if it successfully stopped the cluster
      result = true
    end
  end
end
