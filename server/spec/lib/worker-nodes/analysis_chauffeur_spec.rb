require 'spec_helper'

describe 'AnalysisChauffeur' do
  before :all do
    @library_path = '/data/worker-nodes'
    unless Dir.exists?(@library_path)
      @library_path = File.expand_path('../../worker-nodes')
    end
    FileUtils.cp("#{@library_path}/rails-models/mongoid-vagrant.yml", "#{@library_path}/rails-models/mongoid.yml")
    puts "Library path is #{@library_path}"
    require "#{@library_path}/analysis_chauffeur"
  end

  # need to remove dependency on openstudio to actually test analysischauffeur
  it "should create a chauffeur" do
    #def initialize(uuid_or_path, library_path="/mnt/openstudio", rails_model_path="/mnt/openstudio/rails-models", communicate_method="communicate_mongo")
    @ros = AnalysisChauffeur.new('a_uuid_value', @library_path, "#{@library_path}/rails-models")
    expect(@ros).to_not be_nil
    expect(@ros.datapoint).to_not be_nil
    expect(@ros.datapoint.status).to eq('na')
    expect(@ros.datapoint.uuid).to eq('a_uuid_value')
  end

  after :all do
    FileUtils.rm("#{@library_path}/rails-models/mongoid.yml")
  end
end
