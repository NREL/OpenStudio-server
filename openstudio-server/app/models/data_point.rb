class DataPoint
  include Mongoid::Document

  field :name, :type => String

  belongs_to :analysis
end
