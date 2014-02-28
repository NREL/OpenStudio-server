class ComputeNode
  include Mongoid::Document
  include Mongoid::Timestamps

  field :node_type, :type => String
  field :ip_address, :type => String
  field :hostname, :type => String
  field :user, :type => String
  field :password, :type => String
  field :cores, :type => Integer
  field :ami_id, :type => String
  field :instance_id, :type => String
  field :valid, :type => Boolean, default: false

  # Indexes
  index({hostname: 1}, unique: true)
  index({ip_address: 1}, unique: true)
  index({node_type: 1})

  # Return all the valid IP addresses as a hash in prep for writing to a dataframe
  def self.worker_ips
    worker_ips_hash = {}
    worker_ips_hash[:worker_ips] = []

    ComputeNode.where(valid: true).each do |node|
      (1..node.cores).each { |i| worker_ips_hash[:worker_ips] << node.ip_address }
    end
    Rails.logger.info("worker ip hash: #{worker_ips_hash}")

    worker_ips_hash
  end
  
  # copy the zip file over the various workers and extract the file.
  # if the file already exists, then it will overwrite the file
  # verify the behaviour of the zip extraction on top of an already existing analysis.
  def self.copy_data_to_workers(analysis)
    # copy the datafiles over to the worker nodes
    ComputeNode.where(valid: true).each do |node|
      Rails.logger.info("Configuring node '#{node.node_type}'")
      if node.node_type == 'server'
        Rails.logger.info("Configuring and copying data to master node")
        if !analysis.use_shm
          upload_dir = "/mnt/openstudio/analysis_#{analysis.id}"
          FileUtils.mkdir_p(upload_dir)
          Rails.logger.info("Analysis directory is #{upload_dir}")
          FileUtils.chmod_R(0777, upload_dir)
          FileUtils.copy(analysis.seed_zip.path, "#{upload_dir}/")
          shell_result = `cd #{upload_dir} && unzip -o #{analysis.seed_zip_file_name}`
          FileUtils.chmod_R(0777, upload_dir)
        else
          upload_dir = "/run/shm/openstudio/analysis_#{analysis.id}"
          storage_dir = "/mnt/openstudio/analysis_#{analysis.id}"

          shell_result = `rm -rf #{upload_dir}`
          shell_result = `rm -f #{storage_dir}/*.log && rm -rf #{storage_dir}/analysis_#{analysis.id}`
          FileUtils.mkdir_p(upload_dir)
          FileUtils.chmod_R(0777, upload_dir)
          File.cp(analysis.seed_zip.path, "#{upload_dir}/")
          shell_result = `cd #{upload_dir} && unzip -o #{analysis.seed_zip_file_name}`
          FileUtils.chmod_R(0777, upload_dir)
        end
      else
        Net::SSH.start(node.ip_address, node.user, :password => node.password) do |session|
          if !analysis.use_shm
            upload_dir = "/mnt/openstudio/analysis_#{analysis.id}"
            session.exec!("mkdir -p #{upload_dir} && chmod -R 775 #{upload_dir}") do |channel, stream, data|
              Rails.logger.info(data)
            end
            session.loop

            session.scp.upload!(analysis.seed_zip.path, "#{upload_dir}/")

            session.exec!("cd #{upload_dir} && unzip -o #{analysis.seed_zip_file_name}") do |channel, stream, data|
              logger.info(data)
            end
            session.loop
          else
            upload_dir = "/run/shm/openstudio/analysis_#{analysis.id}"
            storage_dir = "/mnt/openstudio/analysis_#{analysis.id}"
            session.exec!("rm -rf #{upload_dir}") do |channel, stream, data|
              Rails.logger.info(data)
            end
            session.loop

            session.exec!("rm -f #{storage_dir}/*.log && rm -rf #{storage_dir}/analysis_#{analysis.id}") do |channel, stream, data|
              Rails.logger.info(data)
            end
            session.loop

            session.exec!("mkdir -p #{upload_dir} && chmod -R 775 #{upload_dir}") do |channel, stream, data|
              Rails.logger.info(data)
            end
            session.loop

            session.scp.upload!(analysis.seed_zip.path, "#{upload_dir}")

            session.exec!("cd #{upload_dir} && unzip -o #{analysis.seed_zip_file_name} && chmod -R 775 #{upload_dir}") do |channel, stream, data|
              logger.info(data)
            end
            session.loop
          end
        end
      end
    end
  end

  def self.download_results(ip_address, analysis_id, data_point_id)
    remote_file_downloaded = false
    remote_file_exists = false
    local_filename = nil
    
    node = ComputeNode.where(ip_address: ip_address).first
    if node
      remote_filepath = "/mnt/openstudio/analysis_#{analysis_id}"
      remote_filename = "#{remote_filepath}/data_point_#{data_point_id}/data_point_#{data_point_id}.zip"
      remote_filename_reports = "#{remote_filepath}/data_point_#{data_point_id}/data_point_#{data_point_id}_reports.zip" 
      local_filepath = "/mnt/openstudio/analysis_#{analysis_id}"
      local_filename = "#{local_filepath}/data_point_#{data_point_id}.zip"
      local_filename_reports = "#{local_filepath}/data_point_#{data_point_id}_reports.zip" 

      # make sure that the local path exists
      FileUtils.mkdir_p(local_filepath)

      if node.node_type == 'server'
        Rails.logger.info "looks like this is on the server node, just moving #{remote_filename} to #{local_filename}"
        Rails.logger.info "#{remote_filename} exists... moving to new location"
        FileUtils.cp(remote_filename, local_filename)
        FileUtils.cp(remote_filename_reports, local_filename_reports)

        remote_file_downloaded = true
        remote_file_exists = true
      else
        Rails.logger.info "Zip file on worker node. scp over to server #{remote_filename} to #{local_filename}"
        a, b = node.scp_download_file(remote_filename_reports, local_filename_reports)
        remote_file_exists, remote_file_downloaded  = node.scp_download_file(remote_filename, local_filename)
        
        # unzip the contents of the remote file if it existed
        if a && b 
          Rails.logger.info "Reports zip downloaded"
          local_datapoint_path = "#{local_filepath}/data_point_#{data_point_id}"
          FileUtils.mkdir_p(local_datapoint_path)
          unzip_reports = "cd #{local_filepath} && unzip -o #{local_filename_reports} -d #{local_datapoint_path}" 
          Rails.logger.info "Extracting reports zip with command: #{unzip_reports}"
          shell_result = `#{unzip_reports}`
        end
      end
    end 
    
    [remote_file_exists, remote_file_downloaded, local_filename]
  end

  
  def self.get_system_information
    #if Rails.env == "development"  #eventually set this up to be the flag to switch between varying environments

    #end

    Socket.gethostname =~ /os-.*/ ? local_host = true : local_host = false

    # go through the worker node
    ComputeNode.all.each do |node|
      if local_host
        node.ami_id = "Vagrant"
        node.instance_id = "Vagrant"
      else
        if node.node_type == 'server'
          node.ami_id = `curl -sL http://169.254.169.254/latest/meta-data/ami-id`
          node.instance_id = `curl -sL http://169.254.169.254/latest/meta-data/instance-id`
        else
          # have to communicate with the box to get the instance information (ideally this gets pushed from who knew)
          Net::SSH.start(node.ip_address, node.user, :password => node.password) do |session|
            #Rails.logger.info(self.inspect)

            logger.info "Checking the configuration of the worker nodes"
            session.exec!("curl -sL http://169.254.169.254/latest/meta-data/ami-id") do |channel, stream, data|
              Rails.logger.info("Worker node reported back #{data}")
              node.ami_id = data
            end
            session.loop

            session.exec!("curl -sL http://169.254.169.254/latest/meta-data/instance-id") do |channel, stream, data|
              Rails.logger.info("Worker node reported back #{data}")
              node.instance_id = data
            end
            session.loop
          end

        end
      end

      node.save!
    end
  end
  
  def scp_download_file(remote_file, local_file)
    remote_file_exists = false
    remote_file_downloaded = false
    Rails.logger.info "entering scp_download_file"
    Net::SSH.start(self.ip_address, self.user, :password => self.password) do |session|
      Rails.logger.info "Checking if the remote file exists"
      session.exec!("if [ -e '#{remote_file}' ]; then echo -n 'true'; else echo -n 'false'; fi") do |channel, stream, data|
        Rails.logger.info("check remote file data is #{data}")
        if data == 'true'
          remote_file_exists = true
        end
      end
      session.loop

      Rails.logger.info "remote file exists flag is #{remote_file_exists} for #{remote_file}"
      if remote_file_exists
        Rails.logger.info "Trying to download #{remote_file} to #{local_file}"
        if !session.scp.download!(remote_file, local_file)
          remote_file_downloaded = false
          Rails.logger.info "ERROR trying to download datapoint from remote server"
        else
          remote_file_downloaded = true
        end

        #todo: test the deletion of the zip file
        #session.exec!( "cd #{remote_file_path} && rm -f #{remote_filename}" ) do |channel, stream, data|
        #  logger.info(data)
        #end
        #session.loop
      end
    end #session
    
    # return both booleans
    Rails.logger.info "leaving scp_download_file"
    [remote_file_exists, remote_file_downloaded]          
  end
end
