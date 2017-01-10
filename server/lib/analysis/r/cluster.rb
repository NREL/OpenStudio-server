#*******************************************************************************
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
#*******************************************************************************

require 'rserve/simpler'

module Analysis::R
  class Cluster
    attr_reader :started

    def initialize(r_session, analysis_id)
      @r = r_session
      @analysis_id = analysis_id
      @started = false

      # load the required libraries for cluster management
      @r.converse "print('Configuring R Cluster - Loading Libraries')"
      @r.converse 'library(parallel)'
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
      @r.command do
        %{
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
      @r.command(ips: ip_addresses.to_dataframe) do
        %{
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
             cl <- makePSOCKcluster(ips[,1], master='openstudio.server', outfile="/tmp/snow.log")
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
          @r.command do
            %{
              init <- function(x){
                ruby_command <- "cd /mnt/openstudio && #{RUBY_BIN_DIR}/bundle exec ruby"
                y <- paste(ruby_command," /mnt/openstudio/worker_init_final.rb -a #{analysis_id} -s #{state}",sep="")
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
          # Rails.logger.info c.inspect
          result = (c.size == uniq_ips[:worker_ips].size) && (c.map { |i| i.last == 'true' }.all?)
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
