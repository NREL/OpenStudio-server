# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

# Make sure to not make this a feature, otherwise the spec_helper will try to run the jobs in the foreground
RSpec.describe 'RunSingle', type: :feature do
  before :all do
    @previous_job_manager = Rails.application.config.job_manager
    Rails.application.config.job_manager = :delayed_job
  end

  after :all do
    Rails.application.config.job_manager = @previous_job_manager
  end

  before do
    # Look at DatabaseCleaner gem in the future to deal with this.
    Project.destroy_all
    Delayed::Job.destroy_all
  end

  it 'Runs the analysis', js: true do
    host = "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    expect(host).to match /\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}:\d{2,5}/
    # host = "localhost:3000"
    puts "http://#{host}"
    APP_CONFIG['os_server_host_url'] = "http://#{host}"

    h = JSON.parse(File.read('spec/files/test_model/test_model.json'), symbolize_names: true)

    workdir = 'spec/files/test_model/tmp_run_single'
    FileUtils.mkdir_p workdir unless Dir.exist? workdir

    OpenStudio::Analysis.measure_paths << File.expand_path('spec/files/test_model/measures')
    formulation = OpenStudio::Analysis.load(h)
    formulation.analysis_type = 'single_run'
    formulation.save "#{workdir}/test_model.json"

    expect(Delayed::Job.count).to eq(0)
    options = { hostname: "http://#{host}" }
    api = OpenStudio::Analysis::ServerApi.new(options)
    analysis_id = api.run("#{workdir}/test_model.json",
                          'spec/files/test_model/test_model.zip',
                          formulation.analysis_type)

    expect(Delayed::Job.count).to eq(2)
    # Run the first job then use threads to emulate the multiple queues
    threads = []
    expect(Delayed::Worker.new.run(Delayed::Job.first)).to eq true
    threads << Thread.new(1) do # analysis queue
      expect(Delayed::Worker.new.run(Delayed::Job.first)).to eq true
    end
    threads << Thread.new(2) do # worker/simulations queue
      loop do
        j = Delayed::Job.where(queue: 'simulations').first
        if j
          expect(Delayed::Worker.new.run(j)).to eq true
          break
        end
        sleep 1
      end
    end
    threads.each(&:join)

    expect(Delayed::Job.count).to eq(0)
  end
end
