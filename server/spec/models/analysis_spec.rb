# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

RSpec.describe Analysis, type: :model do
  before :all do
    # delete all the analyses
    Project.destroy_all
    FactoryBot.create(:project_with_analyses).analyses

    @project = Project.first
    @analysis = @project.analyses.first
  end

  after do
    # @analysis.destroy
  end

  it 'has one analysis' do
    expect(@project.analyses.size).to eq 1
  end

  it 'has one project' do
    expect(@analysis.project).not_to be_nil
  end

  it 'has uuid and id the same' do
    expect(@analysis.id).to eq(@analysis.uuid)
  end
end
