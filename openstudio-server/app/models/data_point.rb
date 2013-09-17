class DataPoint
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: ->{ uuid || UUID.generate }
  field :name, :type => String
  field :values, :type => Array
  field :ip_address, :type => String
  field :downloaded, :type => Boolean, default: false
  field :openstudio_datapoint_file_name, :type => String   # make this paperclip?
  field :zip_file_name, :type => String
  field :status, :type => String   # enum of queued, started, completed
  field :output

  belongs_to :analysis
end
