class DataPoint
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :name, :type => String
  field :variable_values # This has been hijacked from OS DataPoint. Use set_variable_values
  field :set_variable_values # By default this is a hash list with the name being the id of the variable and the value is the value it was set to.
  field :ip_address, :type => String
  field :internal_ip_address, :type => String
  field :download_status, :type => String, default: "na"
  field :download_information, :type => String
  field :openstudio_datapoint_file_name, :type => String # make this paperclip?
  field :status, :type => String, default: "na" # enum of queued, started, completed
  field :status_message, :type => String #results of the simulation
  field :eplus_html, :type => String, default: nil #Moped::BSON::Binary # ABUPS Summary
  field :output
  field :results, :type => Hash
  field :run_start_time, :type => DateTime
  field :run_end_time, :type => DateTime
  field :sdp_log_file, :type => Array

  # Relationships
  belongs_to :analysis
  has_many :variable_instances

  # Indexes
  index({uuid: 1}, unique: true)
  index({id: 1}, unique: true)
  index({name: 1})
  index({status: 1})
  index({analysis_id: 1})
  index({uuid: 1, status: 1})
  index({uuid: 1, download_status: 1})
  index({run_start_time: -1, name: 1})
  index({analysis_id:1, iteration: 1, sample: 1})

  # Callbacks
  after_create :verify_uuid

  def save_results_from_openstudio_json
    # Parse the OpenStudio JSON and save the results into a name:value hash instead of the
    # open structure define in the JSON

    if !self.output.nil? && !self.output['data_point'].nil? && !self.output['data_point']['output_attributes'].nil?
      self.results = {}
      self.output['data_point']['output_attributes'].each do |output_hash|
        logger.info(output_hash)
        unless output_hash['value_type'] == "AttributeVector"
          output_hash.has_key?('display_name') ? hash_key = output_hash['display_name'].parameterize.underscore :
              hash_key = output_hash['name'].parameterize.underscore
          #logger.info("hash name will be: #{hash_key} with value: #{output_hash['value']}")
          self["results"][hash_key.to_sym] = output_hash['value']
        end
      end
      self.save!
    end
  end

  def finalize_data_points
    downloaded = false
    if self.download_status == 'na' && self.status == 'completed'
      # DO NOT DO THIS
      #self.download_status = 'started'
      #self.save!

      # This is becoming more of a post process that is being triggered by the "downloading" of the
      # file.  If we aren't going to download the file, then the child process can have a flag that it
      # checks similar to the downloaded flag.
      Rails.logger.info "post-processing the JSON data that was pushed into the database by the worker"
      self.save_results_from_openstudio_json

      # Somehow flag that we don't care about downloading the results back to the home directory
      Rails.logger.info "trying to download #{self.id}"
      remote_file_exists = false
      remote_file_downloaded = false
      local_filename = nil

      #look up the worker nodes ip address from database. Move this to ComputeNode class and pass in any potential
      # ip addresses that may have finished
      node = ComputeNode.where(ip_address: self.ip_address).first
      if !node.nil?
        remote_filepath = "/mnt/openstudio/analysis_#{self.analysis.id}/analysis"
        remote_filename = "#{remote_filepath}/data_point_#{self.id}/data_point_#{self.id}.zip"
        local_filepath = "/mnt/openstudio/analysis_#{self.analysis.id}"
        local_filename = "#{local_filepath}/data_point_#{self.id}.zip"

        # make sure that the local path exists
        FileUtils.mkdir_p(local_filepath)

        if node.node_type == 'server'
          Rails.logger.info "looks like this is on the server node, just moving #{remote_filename} to #{local_filename}"
          #if File.exists?(remote_filename)
            remote_file_exists = true
            Rails.logger.info "#{remote_filename} exists... moving to new location"
            FileUtils.cp(remote_filename, local_filename)#, :force => true)
            remote_file_downloaded = true
          #else
            Rails.logger.info "#{remote_filename} did not exist"
          #end
        else
          Net::SSH.start(node.ip_address, node.user, :password => node.password) do |session|
            Rails.logger.info "Checking if the remote file exists"
            session.exec!("if [ -e '#{remote_filename}' ]; then echo -n 'true'; else echo -n 'false'; fi") do |channel, stream, data|
              Rails.logger.info("check remote file data is #{data}")
              if data == 'true'
                remote_file_exists = true
              end
            end
            session.loop

            Rails.logger.info "remote file exists flag is #{remote_file_exists} for #{remote_filename}"
            if remote_file_exists
              Rails.logger.info "Trying to download #{remote_filename} to #{local_filename}"
              if !session.scp.download!(remote_filename, local_filename)
                remote_file_downloaded = false
                Rails.logger.info "ERROR trying to download datapoint from remote server"
              else
                remote_file_downloaded = true
              end

              #TODO test the deletion of the zip file
              #session.exec!( "cd #{remote_file_path} && rm -f #{remote_filename}" ) do |channel, stream, data|
              #  logger.info(data)
              #end
              #session.loop
            end
          end #session
        end
      end #wn.ipaddress

      #now add the datapoint path to the database to get it via the server
      if remote_file_exists && remote_file_downloaded
        self.openstudio_datapoint_file_name = local_filename
        self.download_status = 'completed'
        self.save!
        downloaded = true
      elsif remote_file_exists
        self.openstudio_datapoint_file_name = nil
        self.download_status = 'completed'
        self.download_information = 'failed to download the file'
        self.save!
        downloaded = true
      else
        self.download_status = 'completed'
        self.download_information = 'file did not exist on remote system or could not connect to remote system'
        self.save!
        downloaded = true
      end
    end

    return downloaded
  end

  protected

  def verify_uuid
    self.uuid = self.id if self.uuid.nil?
    self.save!
  end


end
