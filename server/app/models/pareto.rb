class Pareto
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :_id, type: String, default: SecureRandom.uuid
  field :name, type: String
  field :x_var, type: String
  field :y_var, type: String
  field :data_points, type: Array, default: []

  # Relationships
  belongs_to :analysis

  # Indexes
  index({ id: 1 }, unique: true)
  index(analysis_id: 1)
end
