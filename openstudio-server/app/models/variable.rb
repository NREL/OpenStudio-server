class Variable
  include Mongoid::Document

  field :name, :type => String
  field :uuid, :type => String

  field :os_data, :type => Hash

  belongs_to :problem
end
