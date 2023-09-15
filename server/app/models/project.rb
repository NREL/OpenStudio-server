# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class Project
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, type: String
  field :_id, type: String, default: -> { uuid || SecureRandom.uuid }
  field :name, type: String, default: ''
  field :display_name, type: String, default: ''

  # Relationships
  has_many :analyses, dependent: :destroy

  # Indexes
  index({ uuid: 1 }, unique: true)
  #index(id: 1)
  index(name: 1)

  # Callbacks
  before_create :set_uuid_from_id
  after_create :verify_uuid

  def create_single_analysis(analysis_uuid, analysis_name, problem_uuid, problem_name)
    analysis = analyses.find_or_create_by(uuid: analysis_uuid)
    analysis.name = analysis_name
    analysis.save!

    problem = analysis.problems.find_or_create_by(uuid: problem_uuid)
    problem.name = problem_name

    analysis
  end

  protected

  def set_uuid_from_id
    self.uuid = id
  end
  
  def verify_uuid
    self.uuid = id if uuid.nil?
    save!
  end
end
