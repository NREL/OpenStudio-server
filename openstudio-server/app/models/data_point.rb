class DataPoint
  include Mongoid::Document
  include Mongoid::Timestamps

  field :_id, :type => String, default: ->{ uuid || UUID.generate }
  field :name, :type => String
  field :values, :type => Array



  belongs_to :analysis
end
