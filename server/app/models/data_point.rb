class DataPoint
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :name, :type => String
  field :values, :type => Array
  field :ip_address, :type => String
  field :internal_ip_address, :type => String
  field :download_status, :type => String, default: "na"
  field :download_information, :type => String
  field :openstudio_datapoint_file_name, :type => String # make this paperclip?
  field :status, :type => String # enum of queued, started, completed
  field :eplus_html, :type => String #Moped::BSON::Binary # ABUPS Summary
  field :output
  field :results, :type => Hash
  field :run_start_time, :type => DateTime
  field :run_end_time, :type => DateTime
  field :run_time_log, :type => Array
  field :sdp_log_file, :type => Array

  # Relationships
  belongs_to :analysis

  # Indexes
  index({uuid: 1}, unique: true)
  index({id: 1}, unique: true)
  index({name: 1}, unique: true)
  index({status: 1})
  index({analysis_id: 1})
  index({uuid: 1, status: 1})
  index({uuid: 1, download_status: 1})

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
          logger.info("hash name will be: #{hash_key} with value: #{output_hash['value']}")
          self["results"][hash_key.to_sym] = output_hash['value']
        end
      end
      self.save!
    end
  end

  def download_datapoint_from_worker
    downloaded = false
    if self.download_status == 'na' && self.status == 'completed'
      # DO NOT DO THIS
      #self.download_status = 'started'
      #self.save!

      # This is becoming more of a post process that is being triggered by the "downloading" of the
      # file.  If we aren't going to download the file, then the child process can have a flag that it
      # checks similar to the downloaded flag.

      # parse results
      Rails.logger.info "post-processing the JSON data that was pushed into the database by the worker"
      self.save_results_from_openstudio_json

      Rails.logger.info "trying to download #{self.id}"
      save_filename = nil
      remote_file_exists = false

      #look up the worker nodes ip address from database
      wn_ip = WorkerNode.where(ip_address: self.ip_address).first
      if !wn_ip.nil?
        Net::SSH.start(wn_ip.ip_address, wn_ip.user, :password => wn_ip.password) do |session|
          #Rails.logger.info(self.inspect)

          remote_filename = "/mnt/openstudio/analysis/data_point_#{self.id}/data_point_#{self.id}.zip"
          save_filename = "/mnt/openstudio/data_point_#{self.id}.zip"

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
            Rails.logger.info "Trying to download #{remote_filename} to #{save_filename}"
            if !session.scp.download!(remote_filename, save_filename)
              save_filename = nil
              Rails.logger.info "ERROR trying to download datapoint from remote server"
            end

            #TODO test the deletion of the zip file
            #session.exec!( "cd /mnt/openstudio && rm -f #{remote_filename}" ) do |channel, stream, data|
            #  logger.info(data)
            #end
            #session.loop
          end
        end #session
      end #wn.ipaddress

      #now add the datapoint path to the database to get it via the server
      if remote_file_exists && !save_filename.nil?
        self.openstudio_datapoint_file_name = save_filename if !save_filename.nil?
        self.download_status = 'completed'
        self.save!
        downloaded = true
      elsif remote_file_exists
        self.openstudio_datapoint_file_name = save_filename if !save_filename.nil?
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
