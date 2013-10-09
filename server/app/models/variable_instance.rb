# Do we want to make this related to the other objects. My instinct right now is no.
class VariableInstance
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :name, :type => String
  field :variable_id, :type => String
  field :variable_name, :type => String # for sanity checking
  field :measure_id, :type => String # for sanity
  field :measure_name, :type => String # for sanity
  field :value  # this is typeless on purpose

  # Relationships
  belongs_to :data_point

  # Indexes
  index({uuid: 1}, unique: true)
  index({id: 1}, unique: true)
  index({name: 1})
  index({variable_id: 1})
  index({measure_id: 1})

  # Callbacks
  after_create :verify_uuid

  protected

  def verify_uuid
    self.uuid = self.id if self.uuid.nil?
    self.save!
  end


end
