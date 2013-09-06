class DataPoint
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: ->{ uuid || UUID.generate }
  field :name, :type => String
  field :values, :type => Array
  #field :analysis_id, :type => String
  field :ip_address, :type => String

  belongs_to :analysis
end
