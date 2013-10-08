class MasterNode
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ip_address, :type => String
  field :hostname, :type => String
  field :user, :type => String
  field :password, :type => String
  field :cores, :type => Integer

  # Indexes
  index({hostname: 1, ip_address: 1}, unique: true)


end
