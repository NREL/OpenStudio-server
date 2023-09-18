# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class Pareto
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :uuid, type: String
  field :_id, type: String, default: -> { uuid || SecureRandom.uuid }
  field :name, type: String
  field :x_var, type: String
  field :y_var, type: String
  field :data_points, type: Array, default: []

  # Relationships
  belongs_to :analysis

  # Indexes
  index({ uuid: 1 }, unique: true)
  #index(id: 1)
  index(analysis_id: 1)

  # Validation
  validates :name, uniqueness: { scope: :analysis_id }
end
