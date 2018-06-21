# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET /analysis/{id}' do
    before { get "/analyses/#{@analysis.id}.json"}

    it 'return analysis' do
      expect(json).not_to be_empty
    end
  end

  describe 'GET /analysis/{id}/data_points' do
    before { get "/analyses/#{@analysis.id}/data_points.json"}

    it 'return data_points' do
      expect(json).not_to be_empty
      # there must be 3 datapoints in the uploaded example
      expect(json.size).to eq(200)
    end
  end

  describe 'GET /analysis/{id}/get' do
    before { get "/analyses/#{@analysis.id}/analysis_data.json"}

    it 'return data_points' do
      expect(json).not_to be_empty
      # Only returns the successful ones, so the 3 in the example file are not valid
      expect(json['data'].size).to eq(200)
    end
  end

end