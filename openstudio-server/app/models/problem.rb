class Problem
  include Mongoid::Document


  has_many :workflow_steps

end
