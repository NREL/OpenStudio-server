# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

RSpec.describe Project, type: :model do
  before :all do
    # delete all the analyses
    Project.destroy_all
    FactoryBot.create(:project_with_analyses).analyses

    @project = Project.first
  end

  after :all do
  end

  it 'has a project' do
    # 'does not have just one project (either 0 or > 2)'
    expect(Project.all.size).to eq 1
  end

  it 'is a project class' do
    puts @project.class
  end

  it 'has uuid and id the same' do
    expect(@project.id).to eq @project.uuid
  end

  it 'has 1 analysis' do
    expect(@project.analyses.size).to eq 1
  end
end
