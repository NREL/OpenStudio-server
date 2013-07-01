class WorkflowStep
  include Mongoid::Document

  #contains variables and workitems as classes
  field :workflow_type, :type => String
  field :apply_index, :type => Integer

  belongs_to :problem

end
