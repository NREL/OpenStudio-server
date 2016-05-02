require 'rails_helper'

RSpec.describe Analysis, type: :model do
  before :all do
    # delete all the analyses
    Project.delete_all
    Analysis.delete_all
    DataPoint.delete_all
    FactoryGirl.create(:project_with_analyses).analyses

    @project = Project.first
    @analysis = @project.analyses.first
  end

  it 'should have one analysis' do
    @project.analyses.count.should eq(1)
  end

  it 'should have one project' do
    @analysis.project.should_not be_nil
  end

  it 'should have uuid and id the same' do
    @analysis.id.should eq(@analysis.uuid)
  end

  after :each do
    # @analysis.destroy
  end
end
