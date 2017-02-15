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

class ComputeNode
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :queues, type: Array
  field :node_type, type: String # TODO: remove this. node_type is in the queues, or make a method
  field :ip_address, type: String
  field :hostname, type: String
  field :port, type: Integer # TODO: remove this
  field :local_hostname, type: String
  field :pid, type: Integer # PID of running delayed job instance
  field :user, type: String # TODO: remove this
  field :password, type: String # TODO: remove this
  field :cores, type: Integer
  field :ami_id, type: String
  field :instance_id, type: String
  field :enabled, type: Boolean, default: false # TODO: Remove this
  field :last_heartbeat_at, type: DateTime, default: Time.now.utc

  # Indexes
  index(hostname: 1)
  index(ip_address: 1)
  index(node_type: 1)
  index({ name: 1, hostname: 1 }, unique: true)

  # Return all the enabled IP addresses as a hash in prep for writing to a dataframe
  def self.worker_ips
    worker_ips_hash = {}
    worker_ips_hash[:worker_ips] = []

    ComputeNode.where(enabled: true).each do |node|
      if node.node_type == 'server'
        (1..node.cores).each { |_i| worker_ips_hash[:worker_ips] << 'localhost' }
      elsif node.node_type == 'worker'
        (1..node.cores).each { |_i| worker_ips_hash[:worker_ips] << node.ip_address }
      end
    end
    logger.info("worker ip hash: #{worker_ips_hash}")

    worker_ips_hash
  end

  # TODO: verify method
  def update_heartbeat
    update(:last_heartbeat_at, Time.now.utc)
  end

  # TODO: verify method
  def self.dead_workers(timeout_seconds)
    where('last_heartbeat_at < ?', Time.now.utc - timeout_seconds.seconds)
  end

  # TODO: verify method
  def self.active_names
    select(:name)
  end

  # Report back the system inforamtion of the node for debugging purposes
  # TODO: Send system information to server, move this to a worker init because this is hitting API limits on amazon
  def self.system_information
    # # if Rails.env == "development"  #eventually set this up to be the flag to switch between varying environments
    #
    # # end
    #
    # Socket.gethostname =~ /os-.*/ ? local_host = true : local_host = false
    #
    # # go through the worker node
    # ComputeNode.all.each do |node|
    #   if local_host
    #     node.ami_id = 'Vagrant'
    #     node.instance_id = 'Vagrant'
    #   else
    #     #   ex: @datapoint.ami_id = m['ami-id'] ? m['ami-id'] : 'unknown'
    #     #   ex: @datapoint.instance_id = m['instance-id'] ? m['instance-id'] : 'unknown'
    #     #   ex: @datapoint.hostname = m['public-hostname'] ? m['public-hostname'] : 'unknown'
    #     #   ex: @datapoint.local_hostname = m['local-hostname'] ? m['local-hostname'] : 'unknown'
    #
    #     if node.node_type == 'server'
    #       node.ami_id = `curl -sL http://169.254.169.254/latest/meta-data/ami-id`
    #       node.instance_id = `curl -sL http://169.254.169.254/latest/meta-data/instance-id`
    #     else
    #       # have to communicate with the box to get the instance information (ideally this gets pushed from who knew)
    #       Net::SSH.start(node.ip_address, node.user, password: node.password) do |session|
    #         # logger.info(self.inspect)
    #
    #         logger.info 'Checking the configuration of the worker nodes'
    #         session.exec!('curl -sL http://169.254.169.254/latest/meta-data/ami-id') do |_channel, _stream, data|
    #           logger.info("Worker node reported back #{data}")
    #           node.ami_id = data
    #         end
    #         session.loop
    #
    #         session.exec!('curl -sL http://169.254.169.254/latest/meta-data/instance-id') do |_channel, _stream, data|
    #           logger.info("Worker node reported back #{data}")
    #           node.instance_id = data
    #         end
    #         session.loop
    #       end
    #
    #     end
    #   end
    #
    #   node.save!
    # end
  end

  # This method is currently not used, but was previously for reading in the
  # configuration information from a file. This can be removed entirely
  # once the API for loading nodes into the app is finished.
  def load_from_file
    # delete the master and workers and reload them every
    # single time an analysis is initialized
    # Todo: do not delete all the compute nodes
    ComputeNode.destroy_all

    logger.info 'initializing workers'

    # load in the master and worker information if it doesn't already exist
    ip_file = '/home/ubuntu/ip_addresses'
    unless File.exist?(ip_file)
      ip_file = '/data/launch-instance/ip_addresses' # somehow check if this is a vagrant box -- RAILS ENV?
    end

    if File.exist? ip_file
      ips = File.read(ip_file).split("\n")
      ips.each do |ip|
        cols = ip.split('|')
        # TODO: rename this from master to server. The database calls this server
        if cols[0] == 'master'
          node = ComputeNode.find_or_create_by(node_type: 'server', ip_address: cols[1])
          node.hostname = cols[2]
          node.cores = cols[3]
          node.user = cols[4]
          node.password = cols[5].chomp
          node.enabled = cols[6].chomp == 'true'
          node.save!

          logger.info("Server node #{node.inspect}")
        elsif cols[0] == 'worker'
          node = ComputeNode.find_or_create_by(node_type: 'worker', ip_address: cols[1])
          node.hostname = cols[2]
          node.cores = cols[3]
          node.user = cols[4]
          node.password = cols[5].chomp
          node.enabled = false
          if cols[6] && cols[6].chomp == 'true'
            node.enabled = true
          end
          node.save!

          logger.info("Worker node #{node.inspect}")
        end
      end
    end

    # get server and worker characteristics
    # 4/14/15 Disable for now because there is not easy way to get this data back to the server without having
    # to ssh into the box from the server user (nobody). Probably move this over to the worker initialization script.
    # ComputeNode.system_information
  end

  def scp_download_file(session, remote_file, local_file, remote_file_path)
    remote_file_exists = false
    remote_file_downloaded = false

    # Timeout After 2 Minutes / 120 seconds
    retries = 0
    begin
      Timeout.timeout(120) do
        logger.info 'Checking if the remote file exists'
        session.exec!("if [ -e '#{remote_file}' ]; then echo -n 'true'; else echo -n 'false'; fi") do |_channel, _stream, data|
          # logger.info("Check remote file data is #{data}")
          remote_file_exists = true if data == 'true'
        end
        session.loop

        logger.info "Remote file exists flag is '#{remote_file_exists}' for '#{remote_file}'"
        if remote_file_exists
          logger.info "Downloading #{remote_file} to #{local_file}"
          if session.scp.download!(remote_file, local_file, preserve: true)
            remote_file_downloaded = true
          else
            remote_file_downloaded = false
            logger.info 'ERROR trying to download datapoint from remote worker'
          end

          if remote_file_downloaded
            logger.info 'Deleting datapoint from remote worker'
            session.exec!("cd #{remote_file_path} && rm -f #{remote_file}") do |_channel, _stream, _data|
            end
            session.loop
          end
        end
      end
    rescue Timeout::Error
      logger.error 'TimeoutError trying to download datapoint from remote server'
      retry if (retries += 1) <= 3
    rescue => e
      logger.error "Exception while trying to download datapoint from remote server #{e.message}"
      retry if (retries += 1) <= 3
    end

    # return both booleans
    [remote_file_exists, remote_file_downloaded]
  end
end
