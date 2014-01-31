if File.exists?("/data/worker-nodes/analysis_chauffeur.rb")
  require "/data/worker-nodes/analysis_chauffeur"
else
  require_relative "../../../../worker-nodes/analysis_chauffeur"
end

describe AnalysisChauffeur do
  before :all do
    #@ros = AnalysisChauffeur.new("a_uuid_value", "/data/worker-nodes", "/data/worker-nodes/rails-models")
  end
  
  it "should create a chauffeur" do
    #expect(@ros).to_not be_nil
  end
end
