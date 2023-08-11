# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'pp'

RSpec.describe 'Pages Exist', type: :feature do
  before :all do
    # delete all the analyses
    Project.destroy_all

    FactoryBot.create(:project_with_analyses).analyses

    @project = Project.first
    @analysis = @project.analyses.first
  end

  describe 'GET /analyses' do
    before { get '/analyses.json' }

    it 'return analyses' do
      expect(json).not_to be_empty
    end

    it 'returns status code 200' do
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /analysis/{id}' do
    before { get "/analyses/#{@analysis.id}.json" }

    it 'return analysis' do
      expect(json).not_to be_empty
    end
  end

  describe 'GET /analysis/{id}/data_points' do
    before { get "/analyses/#{@analysis.id}/data_points.json" }

    it 'return data_points' do
      expect(json).not_to be_empty
      # there must be 3 datapoints in the uploaded example
      expect(json.size).to eq(200)
    end
  end

  describe 'GET /analysis/{id}/get' do
    before { get "/analyses/#{@analysis.id}/analysis_data.json" }

    it 'return data_points' do
      expect(json).not_to be_empty
      # Only returns the successful ones, so the 3 in the example file are not valid
      expect(json['data'].size).to eq(200)
    end
  end
end
