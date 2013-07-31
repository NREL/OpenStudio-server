class Measure
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :problem
end
