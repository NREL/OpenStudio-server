require 'spec_helper'

describe Project do
  before :each do
    #@project = FactoryGirl.create :project
  end

  it "should have a project" do
    Project.all.size.should eq(1), 'does not have one project'
  end

  after :each do
  end
end