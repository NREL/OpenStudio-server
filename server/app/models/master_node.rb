class MasterNode
  include Mongoid::Document
  include Mongoid::Timestamps

  field :node_type, :type => String # new field to eventually all computers into this list with a flag on type
  field :ip_address, :type => String
  field :hostname, :type => String
  field :user, :type => String
  field :password, :type => String
  field :cores, :type => Integer
  field :valid, :type => Boolean, default: false

  # Indexes
  index({hostname: 1}, unique: true)
  index({ip_address: 1}, unique: true)
  index({node_type: 1})


end
