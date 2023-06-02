# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

RSpec.describe DataPoint, type: :model do
  before do
    Project.destroy_all
    FactoryBot.create(:project_with_analyses).analyses

    @project = Project.first
    @analysis = @project.analyses.first
    @data_point = @analysis.data_points.first
  end

  after do
  end

  it 'has an analysis' do
    expect(@project.analyses).not_to be_nil
  end

  it 'has uuid and id the same' do
    expect(@data_point.id).to eq @data_point.uuid
  end
end
