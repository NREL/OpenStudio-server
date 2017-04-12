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
             res <- evalWithTimeout({
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
        rescue => e
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
