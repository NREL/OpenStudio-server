require 'spec_helper'

describe Project do
  before :all do
    # delete all the analyses
    Project.delete_all
    Analysis.delete_all
    DataPoint.delete_all
    FactoryGirl.create(:project_with_analyses).analyses
    
    @project = Project.first
  end

  it "should have a project" do
    Project.all.size.should eq(1), 'does not have just one project (either 0 or > 2)'
  end
  
  it "should be a project class" do
    puts @project.class 
  end

  it "should have uuid and id the same" do
    @project.id.should eq(@project.uuid)
  end
  
  it "should have 1 analysis" do
    @project.analyses.count.should eq(1)
  end

  after :all do
    
  end
end
