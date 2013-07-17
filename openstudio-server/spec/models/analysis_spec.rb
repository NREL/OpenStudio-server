require 'spec_helper'

describe Analysis do
  before :each do
    #@project = FactoryGirl.create :project
    @analysis = Analysis.find_by(name: "PAT Example")
  end

  it "should have an analysis to run" do
    Analysis.all.size.should eq(1), 'does not have an analysis'
  end

  it "should return a value from R" do
    result = @analysis.start_r_and_run_sample()
  end

  after :each do
  end
end