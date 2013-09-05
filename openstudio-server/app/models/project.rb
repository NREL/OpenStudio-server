class Project
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: ->{ uuid || UUID.generate }
  field :name, :type => String

  has_many :analyses

  before_destroy :remove_dependencies

  def get_problem(problem_name)
    self.analyses.first.problems.find_or_create_by(name: problem_name)
  end

  def create_single_analysis(analysis_uuid, analysis_name, problem_uuid, problem_name)
    analysis = self.analyses.find_or_create_by(uuid: analysis_uuid)
    analysis.name = analysis_name
    puts analysis.inspect
    analysis.save!

    problem = analysis.problems.find_or_create_by(uuid: problem_uuid)
    problem.name = problem_name

    analysis
  end

  protected

  def remove_dependencies
    logger.info("Found #{self.analyses.size} sensors")
    self.analyses.each do |analysis|
      logger.info("removing analysis #{analysis.id}")
      analysis.destroy
    end
  end

end
