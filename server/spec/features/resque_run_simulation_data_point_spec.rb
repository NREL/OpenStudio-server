# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
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

RSpec.describe ResqueJobs::RunSimulateDataPoint, type: :feature, foreground: true, depends_resque: true do
  before :all do
    @previous_job_manager = Rails.application.config.job_manager
    Rails.application.config.job_manager = :resque
  end

  after :all do
    Rails.application.config.job_manager = @previous_job_manager
  end

  before do
    # Look at DatabaseCleaner gem in the future to deal with this.
    Project.destroy_all
    Delayed::Job.destroy_all

    host = "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    puts "App host is: http://#{host}"

    # TODO: Make this a helper of some sort
    options = { hostname: "http://#{host}" }
    # TODO: Convert this over to the openstudio_meta
    @api = OpenStudio::Analysis::ServerApi.new(options)
    APP_CONFIG['os_server_host_url'] = options[:hostname]
  end

  after do
    Delayed::Job.destroy_all
  end

  it 'creates the datapoint', js: true do
    project_id = @api.new_project
    expect(project_id).not_to be nil
    analysis_options = {
      formulation_file: 'spec/files/batch_datapoints/example_csv.json',
      upload_file: 'spec/files/batch_datapoints/example_csv.zip'
    }
    analysis_id = @api.new_analysis(project_id, analysis_options)
    expect(analysis_id).not_to be nil

    a = @api.get_analysis(analysis_id)
    expect(a[:display_name]).to eq 'Example Batch Datapoints Small'

    # expect(...something...)

    # Go set the r_index of the variables because the algorithm normally
    # sets the index
    selected_variables = Variable.variables(analysis_id)
    selected_variables.each_with_index do |v, index|
      v.r_index = index + 1
      v.save
    end

    expect(selected_variables.size).to eq 2
    data_point_data = {
      data_point: {
        name: 'API Test Datapoint',
        ordered_variable_values: [1, 1]
      }
    }

    # TODO: Add this endpoint ot the ServerAPI... the ability to create a datapoint from a hash, not a file.
    a = RestClient.post "#{@api.hostname}/analyses/#{analysis_id}/data_points.json", data_point_data
    a = JSON.parse(a, symbolize_names: true)
    expect(a[:set_variable_values].size).to eq 2
    expect(a[:set_variable_values].values[0]).to eq 1.0
    expect(a[:set_variable_values].values[1]).to eq 1.0
    # expect(a[:set_variable_values].values[2]).to eq 5
    # expect(a[:set_variable_values].values[3]).to eq 20
    # expect(a[:set_variable_values].values[4]).to eq "*Entire Building*"

    expect(a[:_id]).to match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/

    # TODO: What, why is the analysis type unknown!
    _status, j = @api.get_analysis_status_and_json(analysis_id, 'unknown')
    expect(j[:analysis][:data_points].size).to eq 1
  end

  it 'runs a datapoint', js: true do
    project_id = @api.new_project
    expect(project_id).not_to be nil
    analysis_options = {
      formulation_file: 'spec/files/batch_datapoints/example_csv.json',
      upload_file: 'spec/files/batch_datapoints/example_csv.zip'
    }
    analysis_id = @api.new_analysis(project_id, analysis_options)
    dp_file = 'spec/files/batch_datapoints/example_data_point_1.json'
    dp_json = @api.upload_datapoint(analysis_id, datapoint_file: dp_file)
    expect(Delayed::Job.count).to eq(0)

    dp = DataPoint.find(dp_json[:_id])
    datapoint_id = dp.id
    job_id = dp.submit_simulation
    expect(dp.id).to match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
    expect(dp.analysis.id).to eq analysis_id

    # check the results of the simulation
    _status, j = @api.get_analysis_status_and_json(analysis_id, 'unknown')
    expect(j[:analysis][:data_points].size).to eq 1
    # puts "accessed http://#{host}/analyses/#{analysis_id}/status.json"

    # get the analysis as html
    a = RestClient.get "#{@api.hostname}/analyses/#{analysis_id}.html"
    expect(a).to include('OpenStudio Cloud Management Console')
    # puts "accessed http://#{host}/analyses/#{analysis_id}.html"

    # get the datapoint as json
    j = @api.get_datapoint(datapoint_id)
    expect(j[:data_point][:name]).to eq('Test Datapoint')
    expect(j[:data_point][:status_message]).to eq('completed normal')
    # The after_enqueue callback appears to cause issues when running the unit tests. I suspect
    # it has to do with running the background jobs in the foreground (i.e. there is not really a queue)
    # See: OpenStudio-server/server/spec/support/background_jobs.rb
    # expect(j[:data_point][:status]).to eq('completed')
    # Check a simple string in the log to make sure the simulation completed.
    puts "datapoint log for #{datapoint_id}: "
    puts j[:data_point][:sdp_log_file].inspect

    found_complete = false
    j[:data_point][:sdp_log_file].each do |line|
      if line.include? 'Completed the EnergyPlus simulation'
        found_complete = true
      end
    end
    expect(found_complete).to eq true

    # get the datapoint as html
    a = RestClient.get "#{@api.hostname}/data_points/#{datapoint_id}.html"
    puts "accessed http://#{@api.hostname}/data_points/#{datapoint_id}.html"

    # Verify that the results exist
    j = @api.get_analysis_results(analysis_id)
    expect(j).to be_a Hash
    expect(j[:data]).to be_an Array

    # verify that the data point has a log
    j = @api.get_datapoint(datapoint_id)
    expect(j[:data_point][:sdp_log_file]).not_to be_empty
  end
end
