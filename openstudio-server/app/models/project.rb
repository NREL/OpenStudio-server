class Project
  include Mongoid::Document

  field :name, :type => String

  has_many :analyses


  def get_problem(problem_name)
    self.analyses.first.problems.find_or_create_by(name: problem_name)
  end

  def create_single_analysis(analysis_name, problem_name)
    analysis = self.analyses.find_or_create_by(name: analysis_name)
    analysis.uuid = UUID.new.generate()  #needs a unique id
    puts analysis.inspect
    analysis.save!
    problem = analysis.problems.find_or_create_by(name: problem_name)
  end

end
