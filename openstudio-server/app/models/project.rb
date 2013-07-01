class Project
  include Mongoid::Document

  field :name, :type => String
  field :analysis_id


  has_many :analyses

end
