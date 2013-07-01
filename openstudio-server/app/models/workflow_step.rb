class WorkflowStep
  include Mongoid::Document

  #contains measures (with contain variables) and workitems as classes
  field :workflow_type, :type => String
  field :index, :type => Integer

  belongs_to :problem
end
