if File.exists?("/data/worker-nodes/analysis_chauffeur.rb")
  require "/data/worker-nodes/analysis_chauffeur"
else
  require_relative "../../../../worker-nodes/analysis_chauffeur"
end

describe AnalysisChauffeur do
  # need to remove dependency on openstudio to actually test analysischauffeur 
  it "should create a chauffeur", :broken => true do
    @ros = AnalysisChauffeur.new("a_uuid_value", "/data/worker-nodes", "/data/worker-nodes/rails-models")
    expect(@ros).to_not be_nil
  end
end
