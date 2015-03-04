class Status
  include Mongoid::Document
  include Mongoid::Timestamps

  field :awake, type: DateTime

end