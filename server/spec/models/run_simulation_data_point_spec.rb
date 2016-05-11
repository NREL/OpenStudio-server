require 'rails_helper'

RSpec.describe RunSimulateDataPoint, :type => :feature do
  before :all do
    # Look at DatabaseCleaner gem in the future to deal with this.
    Project.delete_all
    Analysis.delete_all
    DataPoint.delete_all
    Measure.delete_all
    Variable.delete_all
    Delayed::Job.delete_all

    # I am no longer using this factory for this purpose. It doesn't
    # link up everything, so just post the test using the Analysis Gem.
    #  FactoryGirl.create(:project_with_analyses).analyses
  end

  it 'should run the data point', js: true do
    host = "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    puts "App host is: #{host}"

    # TODO: Make this a helper of some sort
    options = { hostname: "http://#{host}" }
    api = OpenStudio::Analysis::ServerApi.new(options)
    project_id = api.new_project
    expect(project_id).not_to be nil
    analysis_options = {
        formulation_file: 'spec/files/batch_datapoints/example_csv.json',
        upload_file: 'spec/files/batch_datapoints/example_csv.zip',
    }
    analysis_id = api.new_analysis(project_id, analysis_options)
    dp_file = 'spec/files/batch_datapoints/example_data_point_1.json'
    api.upload_datapoint(analysis_id, {datapoint_file: dp_file})

    expect(Delayed::Job.count).to eq(0)

    dp = DataPoint.first

    # Set the os server url for use by the run simulation
    APP_CONFIG['os_server_host_url'] = host

    # Delayed::Job.enqueue "Analysis::#{analysis_type.camelize}".constantize.new(id, aj.id, options), queue: 'analysis'
    a = RunSimulateDataPoint.new(dp.id)
    a.delay(queue: 'simulations').perform
    expect(Delayed::Job.count).to eq(1)

    # Start the work
    expect(Delayed::Worker.new.work_off).to eq [1, 0] # expects 1 success and 0 failures
    expect(Delayed::Job.count).to eq(0)

    # Verify that the results exist
    j = api.get_analysis_results(analysis_id)
    require 'pp'
    pp j
    expect(j).to be_a Hash
    expect(j[:data]).to be_an Array
    # expect(j[:data].size).to be > 0

    # TODO: Check results -- may need different analysis type with annual data
  end

  it 'should create a write lock that is threadsafe' do
    # okay, threadsafe is a misnomer here -- is this really thread safe?
    # if it downloads it twice, then okay, but 100 times, ughly.

    dp = DataPoint.new
    dp.save!
    a = RunSimulateDataPoint.new(dp.id)
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
        while true
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
      File.open(receipt_file, 'w') { |f| f << Time.now}

    end

    puts arr.inspect
    expect(arr.sum).to eq 1
  end


  it 'should sort worker jobs correctly' do
    a = %w(00_Job0 01_Job1 11_Job11 20_Job20 02_Job2 21_Job21)

    a.sort!

    expect(a.first).to eq '00_Job0'
    expect(a.last).to eq '21_Job21'
    expect(a[3]).to eq '11_Job11'
  end

  after :all do
    Delayed::Job.delete_all
  end

end
