#todo: check if we are on vagrant or using the git repo and require correctly
require "/data/worker-nodes/analysis_chauffeur"

describe AnalysisChauffeur do
  before :all do
    @ros = AnalysisChauffeur.new("a_uuid_value", "/data/worker-nodes", "/data/worker-nodes/rails-models")

    #ize(uuid_or_path, library_path="/mnt/openstudio", rails_model_path="/mnt/openstudio/rails-models", communicate_method="communicate_mongo")
    #uuid_or_path, library_path="/mnt/openstudio", communicate_method="communicate_mongo")
  end
  
  it "should create a chauffeur" do
    expect(@ros).to_not be_nil
  end
end
