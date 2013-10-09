require 'spec_helper'

describe Analysis do
  before :all do
    # delete all the analyses
    Project.destroy_all
    Analysis.destroy_all
    @project = FactoryGirl.create :project
    @analysis = FactoryGirl.create :analysis
  end

  it "should have one project" do
    @analysis.project.should_not be_nil
  end

  it "should have uuid and id the same" do
    @analysis.id.should eq(@analysis.uuid)
  end

  after :each do
    #@analysis.destroy
  end
end