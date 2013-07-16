class Project
  include Mongoid::Document

  field :name, :type => String

  has_many :analyses


end
