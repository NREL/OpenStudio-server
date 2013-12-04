module Analysis::R
  class Cluster
    def initialize(r_session, analysis_id)
      @r = r_session
      @analysis_id = analysis_id

      # load the required libraries for cluster management
      @r.converse "print('Configuring R Cluster - Loading Libraries')"
      @r.converse "library(snow)"
      @r.converse "library(RMongo)"
      
      # determine the database name based on the environment
      if Rails.env == "development"
        @db = "os_test"
      elsif Rails.env == "production"
        @db = "os_prod"
      elsif Rails.env == "test"
        @db = "os_test"
      end
      
    end


    # configure the r session, returns true if the flag variable was readable (and true)
    def configure(master_ip)
      result = false
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
            mongo <- mongoDbConnect("#{@db}", host=ip, port=27017)
            flag <- dbGetQueryForKeys(mongo, "analyses", '{_id:"#{@analysis_id}"}', '{run_flag:1}')
    
            print(flag["run_flag"])
            if (flag["run_flag"] == "true"  ){
              print("flag is set to true!")
            }        
            dbDisconnect(mongo)
          }
      end

      out = @r.converse "flag['run_flag'][,1]"
      result = out == "true" ? true : false 
      
      result
    end

    # return a bool whether or not the cluster appears to be "up-and-running"
    def test_cluster

    end

    # start the cluster.  Returns true if the cluster was started, false
    # if the cluster timed out or failed
    def start(ip_addresses)
      result = false
      @r.command(ips: ip_addresses.to_dataframe) do
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
          print("R cluster startup time:")
          print(timetaken)
          }
      end
      result = @r.converse("timeflag")
    end

    def stop
      result = false
      @r.command() do
        %Q{
            stopCluster(cl)
            }
      end

      # todo: how to test if it successfully stopped the cluster
      result = true
    end
  end
end
