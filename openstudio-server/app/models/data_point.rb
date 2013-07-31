class DataPoint
  include Mongoid::Document
  include Mongoid::Timestamps


  field :name, :type => String
  field :uuid, :type => String
  field :values, :type => Array


  belongs_to :analysis
end
