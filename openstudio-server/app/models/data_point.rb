class DataPoint
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :name, :type => String
  field :values, :type => Array
  field :ip_address, :type => String
  field :downloaded, :type => Boolean, default: false
  field :openstudio_datapoint_file_name, :type => String # make this paperclip?
  field :zip_file_name, :type => String
  field :status, :type => String # enum of queued, started, completed
  field :output

  belongs_to :analysis

  #after_save :download_datapoint_from_worker


  def download_datapoint_from_worker
    if !self.downloaded && status == 'completed'
      logger.info "downloading #{self.id}"

      save_filename = nil

      #look up the worker nodes ip address from database
      wn_ip = WorkerNode.where(hostname: self.ip_address).first
      if !wn_ip.nil?
        Net::SSH.start(wn_ip.ip_address, wn_ip.user, :password => wn_ip.password) do |session|
          #Rails.logger.info(self.inspect)

          save_filename = "/mnt/openstudio/data_point_#{self.id}.zip"

          logger.info "Trying to download /mnt/openstudio/analysis/data_point_#{self.id}/data_point_#{self.id}.zip to #{save_filename}"
          if !session.scp.download!("/mnt/openstudio/analysis/data_point_#{self.id}/data_point_#{self.id}.zip", save_filename)
            save_filename = nil
          end

          #TODO add a delete method for the results
          #session.exec!( "cd /mnt/openstudio && unzip -o #{self.seed_zip_file_name}" ) do |channel, stream, data|
          #  logger.info(data)
          #end
          #session.loop
        end
      end

      #now add the datapoint path to the database to get it via the server
      if !save_filename.nil?
        self.openstudio_datapoint_file_name = save_filename if !save_filename.nil?
        self.downloaded = true
        self.save!
      end
    end
  end

end
