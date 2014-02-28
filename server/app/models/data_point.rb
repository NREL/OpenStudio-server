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
  field :output
  field :results, :type => Hash
  field :run_start_time, :type => DateTime
  field :run_end_time, :type => DateTime
  field :sdp_log_file, :type => Array, default: []

  # Relationships
  belongs_to :analysis
  has_many :variable_instances

  # Indexes
  index({uuid: 1}, unique: true)
  index({id: 1}, unique: true)
  index({name: 1})
  index({status: 1})
  index({analysis_id: 1})
  index({uuid: 1, status: 1, download_status: 1})
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

      #look up the worker nodes ip address from database. Move this to ComputeNode class and pass in any potential
      # ip addresses that may have finished
      Rails.logger.info "trying to download #{self.id}"
      remote_file_exists, remote_file_downloaded, local_filename = ComputeNode.download_results(self.ip_address, self.analysis.id, self.id)

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
