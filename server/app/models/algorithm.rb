class Algorithm
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :analysis
end
