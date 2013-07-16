class Analysis
  include Mongoid::Document

  field :uuid
  field :version_uuid
  field :name, :type => String
  field :display_name, :type => String
  field :description, :type => String

  belongs_to :project

  has_many :data_points

  has_one :algorithm
  has_one :problem

end
