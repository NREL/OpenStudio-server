# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module AnalysisLibrary::R
  class Cluster
    attr_reader :started

    def initialize(r_session, analysis_id)
      @r = r_session
      @analysis_id = analysis_id
      @started = false

      # load the required libraries for cluster management
      @r.converse "print('Configuring R Cluster - Loading Libraries')"
      @r.converse 'library(parallel)'
      @r.converse 'library(R.utils)'
      @r.converse 'library(rjson)'

      # set the name of the current database
      # @db_name = AnalysisLibrary::Core.database_name

      # @db_ip = Mongoid.default_client.cluster.servers.first.address.host
      # @db_port = Mongoid.default_client.cluster.servers.first.address.port
    end

    # configure the r session, returns true if the flag variable was readable (and true)
    def configure
      @r.command do
        %{
            print(paste("Current working directory is",getwd()))
            if (file.exists('#{APP_CONFIG['sim_root_path']}/rtimeout')) {
              file.remove('#{APP_CONFIG['sim_root_path']}/rtimeout')
            }

            source(paste('#{APP_CONFIG['r_scripts_path']}','/functions.R',sep=''))

            flag = FALSE
            flag = check_run_flag('#{APP_CONFIG['r_scripts_path']}', '#{APP_CONFIG['os_server_host_url']}', '#{@analysis_id}')
          }
      end

      # note that if result is false it may be because the Rserve session wasn't
      # running right, or the analysis database record was not found
      @r.converse 'flag'
    end

    # start the cluster.  Returns true if the cluster was started, false
    # if the cluster timed out or failed. The IP addresses are passed as a hash
    # of an arrays ip_addresses["ip"] = ["ip1", "ip2", ...]
    def start(ip_addresses)
      @r.command(ips: ip_addresses.to_dataframe) do
        %{
          print("Starting cluster...")
          print(paste("Number of Workers:", nrow(ips)))
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
             res <- R.utils::withTimeout({
             cl <- makePSOCKcluster(ips[,1], master='openstudio.server', outfile="/mnt/openstudio/log/snow.log")
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

      @started = @r.converse('timeflag')
      @started
    end

    # generic method to execute the worker init/finalize methods
    def worker_init_finalize(ip_addresses, analysis_id, state)
      result = false
      uniq_ips = {}
      uniq_ips[:worker_ips] = ip_addresses[:worker_ips].uniq

      # this will start a cluster with only the unique ip addresses, then stop the cluster.
      if start(uniq_ips)
        begin
          # run the initialization script
          # TODO: remove hard coded server ip:port
          @r.command do
            %{
              init <- function(x){
                ruby_command <- "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/bundle exec ruby"
                y <- paste(ruby_command," #{APP_CONFIG['sim_root_path']}/worker_init_final.rb -h #{APP_CONFIG['os_server_host_url']} -a #{analysis_id} -s #{state}",sep="")
                print(paste("Run command",y))
                z <- system(y,intern=TRUE)
                z
              }

              clusterExport(cl,"init")
              r = clusterCall(cl, "init")
              print(paste("clusterCall returned",r))
            }
          end

          # <Array:35181820 [["Parsing Input: [\"-a\", \"c77365d0-45e5-0132-ccc9-14109fdf0b37\"]", ""], ["Parsing Input: [\"-a\", \"c77365d0-45e5-0132-ccc9-14109fdf0b37\"]", ""]]>

          # Verify the result that each cluster ran the scripts (looking for errors only)
          # Check the length and the last result (which should be true)
          c = @r.converse('r')
          result = (c.size == uniq_ips[:worker_ips].size) && c.map { |i| i.last == 'true' }.all?
        rescue StandardError => e
          raise e
        ensure
          stop
        end
      end

      result
    end

    # call the initialization script on each worker node. This will only be executed one time on each worker node (not IP)
    def initialize_workers(ip_addresses, analysis_id)
      worker_init_finalize(ip_addresses, analysis_id, 'initialize')
    end

    # call the finalization script on each worker node
    def finalize_workers(ip_addresses, analysis_id)
      worker_init_finalize(ip_addresses, analysis_id, 'finalize')
    end

    def stop
      if @started
        @r.command do
          %{
              print("Stopping cluster...")
              stopCluster(cl)
              print("Cluster stopped")
            }
        end
      end

      # TODO: how to test if it successfully stopped the cluster
      @started = false
      true
    end
  end
end
