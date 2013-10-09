require 'spec_helper'

describe Project do
  before :all do
    # delete all the analyses
    Project.delete_all
    @project = FactoryGirl.create :project
  end

  it "should have a project" do
    Project.all.size.should eq(1), 'does not have one project'
  end

  it "should have uuid and id the same" do
    @project.id.should eq(@project.uuid)
  end

  after :each do
  end
end