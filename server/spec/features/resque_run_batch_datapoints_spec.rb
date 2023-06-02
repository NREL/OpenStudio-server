# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

# Make sure to not make this a feature, otherwise the spec_helper will try to run the jobs in the foreground. Also,
# make sure that this is not set to foreground, similar reason.
RSpec.describe 'RunBatchDatapoints', type: :feature, depends_resque: true do
  before :all do
    @previous_job_manager = Rails.application.config.job_manager
    Rails.application.config.job_manager = :resque
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
      puts 'Cannot unlink files, will try and continue'
    end

    Resque.workers.each(&:unregister_worker)
    Resque.queues.each { |q| Resque.redis.del "queue:#{q}" }

    host = "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    puts "App host is: http://#{host}"

    # TODO: Make this a helper of some sort
    options = { hostname: "http://#{host}" }
    # TODO: Convert this over to the openstudio_meta
    @api = OpenStudio::Analysis::ServerApi.new(options)
    APP_CONFIG['os_server_host_url'] = options[:hostname]
  end

  it 'Runs the analysis', js: true do
    analysis_id = @api.run('spec/files/batch_datapoints/example_csv_with_scripts.json',
                           'spec/files/batch_datapoints/example_csv_with_scripts.zip',
                           'batch_datapoints')

    # analysis_wrappers
    analysis_wrapper_worker = Resque::Worker.new('analysis_wrappers')
    analyses_worker = Resque::Worker.new('analyses')
    sim_worker = Resque::Worker.new('simulations')

    wait_and_run_queue(analysis_wrapper_worker) # there should be two jobs in this queue, batch_datapoints, and batch_run

    # emulate the analyses and simulation queues. Analyses queue waits until the simulations are done
    # before finishing, so thread it.
    threads = []
    threads << Thread.new(1) do
      wait_and_run_queue(analyses_worker)
    end
    threads << Thread.new(1) do
      # First loop waits until a job exists in the queue. Then once it exists, then the second loop processes
      # until all the jobs are finished (only running one simulation at a time).
      sleep 2
      wait_and_run_queue(sim_worker)
    end
    threads.each(&:join)

    # Run finalization script
    wait_and_run_queue(analysis_wrapper_worker) # there should be a single wrapper job for finalization

    status, j = @api.get_analysis_status_and_json(analysis_id, 'batch_run')
    expect(status).to eq 'completed'
    expect(j[:analysis][:data_points].size).to eq 4

    # check the existence of the initialization and finalization scripts
    analysis_path = "#{APP_CONFIG['os_server_project_path']}/server/analyses/#{analysis_id}"
    puts analysis_path
    expect(File.exist?("#{analysis_path}/initialize_ran.txt")).to eq true
    expect(File.exist?("#{analysis_path}/finalize_ran.txt")).to eq true

    # check the algorithm results, make sure there is a finalization value that is written from the finalization script
    results = @api.get_analysis(analysis_id)
    puts results
    expect(results[:results][:finalization][:random_value]).to eq 5
    expect(results[:results][:finalization][:number_of_variables]).to eq 2
    expect(results[:results][:finalization][:number_of_datapoints]).to eq 4

    # wait 10 minutes to help debug
    # sleep 600
  end
end
