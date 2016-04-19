class ComputeNode
  include Mongoid::Document
  include Mongoid::Timestamps

  field :node_type, type: String
  field :ip_address, type: String
  field :hostname, type: String
  field :port, type: Integer
  field :local_hostname, type: String
  field :user, type: String
  field :password, type: String
  field :cores, type: Integer
  field :ami_id, type: String
  field :instance_id, type: String
  field :valid, type: Boolean, default: false

  # Indexes
  index({ hostname: 1 })
  index({ ip_address: 1 })
  index(node_type: 1)

  # Return all the valid IP addresses as a hash in prep for writing to a dataframe
  def self.worker_ips
    worker_ips_hash = {}
    worker_ips_hash[:worker_ips] = []

    ComputeNode.where(valid: true).each do |node|
      if node.node_type == 'server'
        (1..node.cores).each { |_i| worker_ips_hash[:worker_ips] << 'localhost' }
      elsif node.node_type == 'worker'
        (1..node.cores).each { |_i| worker_ips_hash[:worker_ips] << node.ip_address }
      end
    end
    Rails.logger.info("worker ip hash: #{worker_ips_hash}")

    worker_ips_hash
  end

  # Report back the system inforamtion of the node for debugging purposes
  def self.system_information
    # # if Rails.env == "development"  #eventually set this up to be the flag to switch between varying environments
    #
    # # end
    #
    # # TODO: move this to a worker init because this is hitting API limits on amazon
    # Socket.gethostname =~ /os-.*/ ? local_host = true : local_host = false
    #
    # # go through the worker node
    # ComputeNode.all.each do |node|
    #   if local_host
    #     node.ami_id = 'Vagrant'
    #     node.instance_id = 'Vagrant'
    #   else
    #     # TODO: convert this all over to Facter -- acutally remove this!
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
    #         # Rails.logger.info(self.inspect)
    #
    #         logger.info 'Checking the configuration of the worker nodes'
    #         session.exec!('curl -sL http://169.254.169.254/latest/meta-data/ami-id') do |_channel, _stream, data|
    #           Rails.logger.info("Worker node reported back #{data}")
    #           node.ami_id = data
    #         end
    #         session.loop
    #
    #         session.exec!('curl -sL http://169.254.169.254/latest/meta-data/instance-id') do |_channel, _stream, data|
    #           Rails.logger.info("Worker node reported back #{data}")
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

  def scp_download_file(session, remote_file, local_file, remote_file_path)
    remote_file_exists = false
    remote_file_downloaded = false

    # Timeout After 2 Minutes / 120 seconds
    retries = 0
    begin
      Timeout.timeout(120) do
        Rails.logger.info 'Checking if the remote file exists'
        session.exec!("if [ -e '#{remote_file}' ]; then echo -n 'true'; else echo -n 'false'; fi") do |_channel, _stream, data|
          # Rails.logger.info("Check remote file data is #{data}")
          remote_file_exists = true if data == 'true'
        end
        session.loop

        Rails.logger.info "Remote file exists flag is '#{remote_file_exists}' for '#{remote_file}'"
        if remote_file_exists
          Rails.logger.info "Downloading #{remote_file} to #{local_file}"
          if session.scp.download!(remote_file, local_file, preserve: true)
            remote_file_downloaded = true
          else
            remote_file_downloaded = false
            Rails.logger.info 'ERROR trying to download data point from remote worker'
          end

          if remote_file_downloaded
            Rails.logger.info 'Deleting data point from remote worker'
            session.exec!("cd #{remote_file_path} && rm -f #{remote_file}") do |_channel, _stream, _data|
            end
            session.loop
          end
        end
      end
    rescue Timeout::Error
      Rails.logger.error 'TimeoutError trying to download data point from remote server'
      retry if (retries += 1) <= 3
    rescue => e
      Rails.logger.error "Exception while trying to download data point from remote server #{e.message}"
      retry if (retries += 1) <= 3
    end

    # return both booleans
    [remote_file_exists, remote_file_downloaded]
  end
end
