#todo: check if we are on vagrant or using the git repo and require correctly
require "/data/worker-nodes/analysis_chauffeur"

describe AnalysisChauffeur do
  before :all do
    #@ros = AnalysisChauffeur.new("a_uuid_value", "/data/worker-nodes", "/data/worker-nodes/rails-models")
  end
  
  it "should create a chauffeur" do
    #expect(@ros).to_not be_nil
  end
end
