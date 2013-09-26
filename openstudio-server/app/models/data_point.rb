class DataPoint
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :name, :type => String
  field :values, :type => Array
  field :ip_address, :type => String
  field :download_status, :type => String, default: "na"
  field :openstudio_datapoint_file_name, :type => String # make this paperclip?
  field :zip_file_name, :type => String
  field :status, :type => String # enum of queued, started, completed
  field :output
  field :results

  belongs_to :analysis

  def save_results_from_openstudio_json
    # Parse the OpenStudio JSON and save the results into a name:value hash instead of the
    # open structure define in the JSON

    if !self.output.nil? || !self.output['data_point'].nil? || !self.output['data_point']['output_attributes'].nil?
      self.output['data_point']['output_attributes'].each do |output_hash|
        logger.info(output_hash)

        # This isn't worker right now
        self.results = {}
        if output_hash.has_key?('name')
          hash_key = output_hash['name'].gsub(" ","").underscore
          logger.info("hash name will be #{hash_key}")
          self.results[hash_key.to_sym] = output_hash['value']
        end
        self.save!
      end
    end
  end

  def download_datapoint_from_worker
    if self.download_status == 'na' && status == 'completed'
      self.download_status = 'downloading'
      self.save!
      # This is becoming more of a post process that is being triggered by the "downloading" of the
      # file.  If we aren't going to download the file, then the child process can have a flag that it
      # checks similar to the downloaded flag.


      logger.info "downloading #{self.id}"
      save_filename = nil

      #look up the worker nodes ip address from database
      wn_ip = WorkerNode.where(hostname: self.ip_address).first
      if !wn_ip.nil?
        Net::SSH.start(wn_ip.ip_address, wn_ip.user, :password => wn_ip.password) do |session|
          #Rails.logger.info(self.inspect)

          remote_filename = "/mnt/openstudio/analysis/data_point_#{self.id}/data_point_#{self.id}.zip"
          save_filename = "/mnt/openstudio/data_point_#{self.id}.zip"

          logger.info "Trying to download #{remote_filename} to #{save_filename}"
          if !session.scp.download!(remote_filename, save_filename)
            save_filename = nil
          end

          #TODO test the deletion of the zip file
          #session.exec!( "cd /mnt/openstudio && rm -f #{remote_filename}" ) do |channel, stream, data|
          #  logger.info(data)
          #end
          #session.loop
        end
      end

      #now add the datapoint path to the database to get it via the server
      if !save_filename.nil?
        self.openstudio_datapoint_file_name = save_filename if !save_filename.nil?
        logger.info "post-processing the JSON data that was pushed into the database by the worker"
        self.save_results_from_openstudio_json
        self.download_status = 'finished'
        self.save!
      end
    end
  end

end
