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

RSpec.describe DjJobs::RunSimulateDataPoint, type: :feature, foreground: true do
  before :all do
    @previous_job_manager = Rails.application.config.job_manager
    Rails.application.config.job_manager = :delayed_job
  end

  after :all do
    Rails.application.config.job_manager = @previous_job_manager
  end

  before do
    # Look at DatabaseCleaner gem in the future to deal with this.
    begin
      Project.destroy_all
      Delayed::Job.destroy_all
    rescue Errno::EACCES => e
      puts "Cannot unlink files, will try and continue"
    end

    # I am no longer using this factory for this purpose. It doesn't
    # link up everything, so just post the test using the Analysis Gem.
    #  FactoryBot.create(:project_with_analyses).analyses
  end

  after do
    Delayed::Job.destroy_all
  end

  it 'creates the datapoint', js: true do
    host = "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    puts "App host is: #{host}"

    # TODO: Make this a helper of some sort
    options = { hostname: "http://#{host}" }
    api = OpenStudio::Analysis::ServerApi.new(options)
    project_id = api.new_project
    expect(project_id).not_to be nil
    analysis_options = {
      formulation_file: 'spec/files/batch_datapoints/example_csv.json',
      upload_file: 'spec/files/batch_datapoints/example_csv.zip'
    }
    analysis_id = api.new_analysis(project_id, analysis_options)

    puts analysis_id
    expect(analysis_id).not_to be nil

    a = RestClient.get "http://#{host}/analyses/#{analysis_id}.json"

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

    a = RestClient.post "http://#{host}/analyses/#{analysis_id}/data_points.json", data_point_data
    a = JSON.parse(a, symbolize_names: true)
    expect(a[:set_variable_values].size).to eq 2
    expect(a[:set_variable_values].values[0]).to eq 1.0
    expect(a[:set_variable_values].values[1]).to eq 1.0
    # expect(a[:set_variable_values].values[2]).to eq 5
    # expect(a[:set_variable_values].values[3]).to eq 20
    # expect(a[:set_variable_values].values[4]).to eq "*Entire Building*"

    expect(a[:_id]).to match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/

    a = RestClient.get "http://#{host}/analyses/#{analysis_id}/status.json"
    a = JSON.parse(a, symbolize_names: true)
    expect(a[:analysis][:data_points].size).to eq 1

    # test using the script
    script = File.expand_path('../docker/R/api_create_datapoint.rb', Rails.root)
    puts script
  end

  it 'runs a datapoint', js: true do
    host = "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    # Set the os server url for use by the run simulation
    APP_CONFIG['os_server_host_url'] = "http://#{host}"

    # TODO: Make this a helper of some sort
    options = { hostname: "http://#{host}" }
    api = OpenStudio::Analysis::ServerApi.new(options)
    project_id = api.new_project
    expect(project_id).not_to be nil
    analysis_options = {
      formulation_file: 'spec/files/batch_datapoints/example_csv.json',
      upload_file: 'spec/files/batch_datapoints/example_csv.zip'
    }
    analysis_id = api.new_analysis(project_id, analysis_options)
    dp_file = 'spec/files/batch_datapoints/example_data_point_1.json'
    dp_json = api.upload_datapoint(analysis_id, datapoint_file: dp_file)
    expect(Delayed::Job.count).to eq(0)

    dp = DataPoint.find(dp_json[:_id])
    datapoint_id = dp.id
    job_id = dp.submit_simulation
    expect(dp.id).to match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
    expect(dp.analysis.id).to eq analysis_id
    expect(Delayed::Job.count).to eq(0)

    # check the results of the simulation
    # check the results of the simulation
    a = RestClient.get "http://#{host}/analyses/#{analysis_id}/status.json"
    a = JSON.parse(a, symbolize_names: true)
    expect(a[:analysis][:data_points].size).to eq 1
    # puts "accessed http://#{host}/analyses/#{analysis_id}/status.json"

    # get the analysis as html
    a = RestClient.get "http://#{host}/analyses/#{analysis_id}.html"
    expect(a).to include('OpenStudio Cloud Management Console')
    # puts "accessed http://#{host}/analyses/#{analysis_id}.html"

    # get the datapoint as json
    a = RestClient.get "http://#{host}/data_points/#{datapoint_id}.json"
    a = JSON.parse(a, symbolize_names: true)
    puts a
    
    # l = RestClient.get "http://#{host}/data_points/#{datapoint_id}/download_result_file?filename=#{datapoint_id}.log"
    # expect(l).to eq('hack to inspect oscli output')

    expect(a[:data_point][:name]).to eq('Test Datapoint')
    expect(a[:data_point][:status_message]).to eq('completed normal')
    expect(a[:data_point][:status]).to eq('completed')
    # puts "accessed http://#{host}/data_points/#{datapoint_id}.json"
    #
    # print log file before it is deleted
    Rails.logger.info "datapoint log for #{datapoint_id}: #{a[:data_point][:sdp_log_file]}"
    # get the datapoint as html
    a = RestClient.get "http://#{host}/data_points/#{datapoint_id}.html"
    puts "accessed http://#{host}/data_points/#{datapoint_id}.html"

    # pulling data point simulation log
    l = RestClient.get "http://#{host}/data_points/#{datapoint_id}/download_result_file?filename=#{datapoint_id}.log"
    expect(l.include?('Oscli output:')).to eq(true)

    # Verify that the results exist
    j = api.get_analysis_results(analysis_id)
    expect(j).to be_a Hash
    expect(j[:data]).to be_an Array

    # verify that the data point has a log
    j = api.get_datapoint(datapoint_id)
    puts JSON.pretty_generate(j)
    expect(j[:data_point][:sdp_log_file]).not_to be_empty
  end

  it 'creates a write lock that is threadsafe' do
    # okay, threadsafe is a misnomer here -- is this really thread safe?
    # if it downloads it twice, then okay, but 100 times, ughly.

    project = Project.new
    project.save!
    analysis = Analysis.new(project_id: project.id)
    analysis.save!
    dp = DataPoint.new(analysis_id: analysis.id)
    dp.save!
    a = DjJobs::RunSimulateDataPoint.new(dp.id)
    write_lock_file = 'spec/files/tmp/write.lock'
    receipt_file = 'spec/files/tmp/write.receipt'
    FileUtils.mkdir_p 'spec/files/tmp'
    File.delete(write_lock_file) if File.exist? write_lock_file
    File.delete(receipt_file) if File.exist? receipt_file

    thread_count = 500
    arr = Array.new(thread_count)
    puts arr.inspect
    Parallel.each(0..thread_count, in_threads: thread_count) do |index|
      arr[index] = 0 if File.exist? receipt_file

      # TODO: Break this code out into its own class and test it there
      if File.exist? write_lock_file
        # wait until receipt file appears then return
        loop do
          break if File.exist? receipt_file

          sleep 1
        end

        arr[index] = 0
      else
        a.write_lock(write_lock_file) do |_|
          puts "Downloading for index #{index}..."
          arr[index] = 1
          sleep 3
        end
      end
      File.open(receipt_file, 'w') { |f| f << Time.now }
    end

    puts arr.inspect
    expect(arr.sum).to be < 5
  end

  it 'sorts worker jobs correctly' do
    a = ['00_Job0', '01_Job1', '11_Job11', '20_Job20', '02_Job2', '21_Job21']

    a.sort!

    expect(a.first).to eq '00_Job0'
    expect(a.last).to eq '21_Job21'
    expect(a[3]).to eq '11_Job11'
  end
end

RSpec.describe DjJobs::RunSimulateDataPoint, type: :feature, depends_resque: true do
  before :each do
    begin
      Project.destroy_all
    rescue Errno::EACCES => e
      puts "Cannot unlink files, will try and continue"
    end
    FactoryBot.create(:project_with_analyses).analyses

    @project = Project.first
    @analysis = @project.analyses.first
    @data_point = @analysis.data_points.first
  end

  it 'launches a script successfully' do
    job = DjJobs::RunSimulateDataPoint.new(@data_point.id)

    # copy over the test script to the directory
    FileUtils.mkdir_p "#{job.send :analysis_dir}/scripts/data_point"
    FileUtils.cp('spec/files/worker_init_test.sh', "#{job.send :analysis_dir}/scripts/data_point")
    FileUtils.cp('spec/files/worker_init_test.args', "#{job.send :analysis_dir}/scripts/data_point")

    # call the private method for testing purposes
    job.send :run_script_with_args, 'worker_init_test'

    # verify that a log file was created

    log_file = "#{job.send :analysis_dir}/data_point_#{@data_point.id}/worker_init_test.log"
    expect(File.exist? log_file).to eq true
    if File.exist? log_file
      file_contents =  File.read(log_file)
      expect(file_contents.include? 'argument number 1')
    end

    # verify that the init log is attached to the datapoint
    # For some reason the worker_logs aren't working within the testing framework. They work in
    # actual deployment. # TODO: Figure out why worker_logs don't show up for tests
    puts @data_point.worker_logs.inspect
  end
end
