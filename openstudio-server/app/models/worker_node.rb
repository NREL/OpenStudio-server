class WorkerNode
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ip_address, :type => String
  field :hostname, :type => String
  field :user, :type => String
  field :password, :type => String
  field :cores, :type => Integer
end
