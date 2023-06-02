# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

RSpec.describe PreflightImage, type: :model do
  before :all do
    # delete all the analyses
    Project.destroy_all
    FactoryBot.create(:project_with_analyses).analyses

    @project = Project.first
    @analysis = @project.analyses.first
  end

  it 'adds a variable and preflight image' do
    # create a measure to us in the analysis
    new_measure = Measure.new(analysis_id: @analysis.id)
    new_measure.save!
    new_var = Variable.new(analysis_id: @analysis.id, measure_id: new_measure.id)
    new_var.save!
    @analysis.variables << new_var
    pfi = PreflightImage.add_from_disk(new_var.id, 'histogram', '../files/r_plot_histogram.png')
    new_var.preflight_images << pfi unless new_var.preflight_images.include?(pfi)

    expect(new_var.preflight_images.count).to eq(1)
  end
end
