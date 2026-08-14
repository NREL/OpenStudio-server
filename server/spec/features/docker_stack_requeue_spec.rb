# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

#################################################################################
# To Run this test manually:
#
#   start a server stack with /spec added and ssh into the Web container
#   you may need to ADD the spec folder in the Dockerfile
#   >ruby /opt/openstudio/bin/openstudio_meta install_gems
#   >bundle install --with development test
#   >rspec spec/features/docker_stack_algo_spec.rb
#
#################################################################################

require 'rails_helper'
require 'rest-client'
require 'net/http'
require 'json'

# Set obvious paths for start-local & run-analysis invocation
RUBY_CMD = 'ruby'
BUNDLE_CMD = 'bundle exec ruby'

# Docker tests have these hard coded paths
META_CLI = File.absolute_path('/opt/openstudio/bin/openstudio_meta')
PROJECT = File.absolute_path(File.join(File.dirname(__FILE__), '../files/'))
HOST = '127.0.0.1'

# For testing locally
#META_CLI = File.absolute_path('C:\ParametricAnalysisTool-3.1.0\pat\OpenStudio-server\bin\openstudio_meta')
#PROJECT = File.absolute_path(File.join(File.dirname(__FILE__), '../../files/'))
#HOST = 'localhost:8080'
##require 'rspec'
##include RSpec::Matchers
#RUBY_CMD = 'C:\ParametricAnalysisTool-3.1.0\pat\ruby\bin\ruby.exe'

puts "Project folder is: #{PROJECT}"
puts "META_CLI is: #{META_CLI}"
puts "App host is: http://#{HOST}"
#docker_ps = system('docker-compose ps')
#puts "Docker ps: #{docker_ps.to_s}"

# the actual tests
RSpec.describe 'RunRequeue', type: :feature, algo: true do
  before :all do
    @host = HOST
    @project = PROJECT
    @meta_cli = META_CLI
    @ruby_cmd = RUBY_CMD
    @bundle_cmd = BUNDLE_CMD

    options = { hostname: "http://#{@host}" }
    # TODO: Convert this over to the openstudio_meta
    # @api = OpenStudio::Analysis::ServerApi.new(options)
    # You are still going to want the ServerApi to grab results. You can replace a bunch of the
    # RestClient calls below.
  end

  it 'run lhs analysis', :lhs, js: true do
  
    def requeue_datapoint(job_args)
      uri = URI("http://#{@host}/data_points/#{job_args}/requeue")
      puts "REQUEUE: URI #{uri}"
      request = Net::HTTP::Post.new(uri)
      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
      end
      puts "REQUEUE: Requeued datapoint with UUID #{job_args}. Response: #{response.code} #{response.message}"
      return response.code
    rescue => e
      puts "REQUEUE: Failed to requeue datapoint with UUID #{job_args}. Error: #{e.message}"
      return nil
    end

    # setup expected results
    lhs = [{electricity_consumption_cvrmse: 11.67547,
            electricity_consumption_nmbe: -9.67134,
            natural_gas_consumption_cvrmse: 88.97549886,
            natural_gas_consumption_nmbe: -71.2423
           },
           {
            electricity_consumption_cvrmse: 22.57385,
            electricity_consumption_nmbe: 21.54758,
            natural_gas_consumption_cvrmse: 123.6693321,
            natural_gas_consumption_nmbe: 89.28405
           },
           {
            electricity_consumption_cvrmse: 19.81253,
            electricity_consumption_nmbe: -18.97733,
            natural_gas_consumption_cvrmse: 81.09041,
            natural_gas_consumption_nmbe: -61.5712
           },
           {
            electricity_consumption_cvrmse: 40.76865,
            electricity_consumption_nmbe: -41.10892,
            natural_gas_consumption_cvrmse: 99.89285,
            natural_gas_consumption_nmbe: 70.79368
           },
           {
            electricity_consumption_cvrmse: 55.14293,
            electricity_consumption_nmbe: -56.83036,
            natural_gas_consumption_cvrmse: 43.52242,
            natural_gas_consumption_nmbe: 22.80775
           },
           {
            electricity_consumption_cvrmse: 79.92222,
            electricity_consumption_nmbe: -82.94121,
            natural_gas_consumption_cvrmse: 69.4762,
            natural_gas_consumption_nmbe: -50.88541
           },
           # OpenStudio 3.10.0 results
           {
            electricity_consumption_cvrmse: 11.80643639,
            electricity_consumption_nmbe: -9.992706452,
            natural_gas_consumption_cvrmse: 88.97549886,
            natural_gas_consumption_nmbe: -71.2422889
           },
           {
            electricity_consumption_cvrmse: 22.26135019,
            electricity_consumption_nmbe: 21.07474074,
            natural_gas_consumption_cvrmse: 123.6693321,
            natural_gas_consumption_nmbe: 89.28433483
           },
           {
            electricity_consumption_cvrmse: 19.92877245,
            electricity_consumption_nmbe: -19.20285379,
            natural_gas_consumption_cvrmse: 81.09035156,
            natural_gas_consumption_nmbe: -61.5710272
           },
           {
            electricity_consumption_cvrmse: 41.31502887,
            electricity_consumption_nmbe: -41.6127891,
            natural_gas_consumption_cvrmse: 99.892904,
            natural_gas_consumption_nmbe: 70.79385513
           },
           {
            electricity_consumption_cvrmse: 55.38893763588019,
            electricity_consumption_nmbe: -57.11056265094546,
            natural_gas_consumption_cvrmse: 43.52243818,
            natural_gas_consumption_nmbe: 22.80778241
           },
           {
            electricity_consumption_cvrmse: 80.27419288,
            electricity_consumption_nmbe: -83.30621751,
            natural_gas_consumption_cvrmse: 69.47538644,
            natural_gas_consumption_nmbe: -50.88411437
           }]
    
    # setup bad results
    lhs_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]

    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_sleep.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a lhs"
    puts "run command: #{command}"
    run_analysis = system(command)
    expect(run_analysis).to be true

    a = RestClient.get "http://#{@host}/analyses.json"
    a = JSON.parse(a, symbolize_names: true)
    a = a.sort { |x, y| x[:created_at] <=> y[:created_at] }.reverse
    expect(a).not_to be_empty
    analysis = a[0]
    analysis_id = analysis[:_id]

    status = 'queued'
    timeout_seconds = 360
    sleep 10
    begin
      ::Timeout.timeout(timeout_seconds) do
        # get the analysis pages
        get_count = 0
        get_count_max = 50
        requeue_count = 0
        while status != 'completed'
          begin
            a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/status.json"
            a = JSON.parse(a, symbolize_names: true)
            analysis_type = a[:analysis][:analysis_type]
            expect(analysis_type).to eq('batch_run')

            # analysis_type = a[:analysis][:jobs][0][:analysis_type]
            # expect(analysis_type).to eq('lhs')

            status = a[:analysis][:status]
            expect(status).not_to be_nil
            puts "Accessed pages for analysis: #{analysis_id}, analysis_type: #{analysis_type}, status: #{status}"

            # get all data points in this analysis
            a = RestClient.get "http://#{@host}/data_points.json"
            a = JSON.parse(a, symbolize_names: true)
            data_points = []
            a.each do |data_point|
              if data_point[:analysis_id] == analysis_id
                data_points << data_point
              end
            end
            requeue_count += 1
            # confirm that queueing is working
            data_points.each do |data_point|
              # get the datapoint pages
              data_point_id = data_point[:_id]
              expect(data_point_id).not_to be_nil

              a = RestClient.get "http://#{@host}/data_points/#{data_point_id}.json"
              a = JSON.parse(a, symbolize_names: true)
              expect(a).not_to be_nil

              data_points_status = a[:data_point][:status]
              expect(data_points_status).not_to be_nil
              puts "Accessed pages for data_point #{data_point_id}, data_points_status = #{data_points_status}"
              #after 40 seconds requeue the running datapoints
              puts "requeue_count: #{requeue_count}"
              if (requeue_count == 4) && (data_points_status == 'started')
                puts "requeueing datapoint: #{data_point_id}"
                response_code = requeue_datapoint(data_point_id)
                expect(response_code).not_to be_nil
                expect(response_code).to eq("302")
              end
              
            end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
            get_count += 1 # Increment the retry counter
            retry if get_count <= get_count_max
          end
          puts ''
          sleep 10
        end
      end
    rescue ::Timeout::Error
      puts "Analysis status is `#{status}` after #{timeout_seconds} seconds; assuming error."
    end
    expect(status).to eq('completed')

    get_count = 0
    get_count_max = 50
    begin
      # confirm that datapoints ran successfully
      dps = RestClient.get "http://#{@host}/data_points.json"
      dps = JSON.parse(dps, symbolize_names: true)
      expect(dps).not_to be_nil

      data_points = []
      dps.each do |data_point|
        if data_point[:analysis_id] == analysis_id
          data_points << data_point
        end
      end
      expect(data_points.size).to eq(6)

      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(2) }
        puts "lhs sim: #{sim}"
        tmp = []
        lhs.each do |x|
          tmp << x.transform_values { |y| y.truncate(2) }
        end
        compare = tmp.include?(sim)
        puts "data_point[:#{data_point[:_id]}] sim is: #{sim}"
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] compare is: #{compare}"

        compare = lhs_bad.include?(sim)
        expect(compare).to be false
      end
    rescue RestClient::ExceptionWithResponse => e
      puts "rescue: #{e} get_count: #{get_count}"
      sleep Random.new.rand(1.0..10.0)
      retry if get_count <= get_count_max
    end
    
    puts 'check logs for mongo index errors'
    a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/debug_log"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.body).not_to include "OperationFailure"
    expect(a.body).not_to include "FATAL"
    expect(a.body).to include "Created indexes"
    
  end # lhs
  
  it 'run 3x lhs analysis', :lhs, js: true do


    puts 'remove any existing projects'
    a = RestClient.get "http://#{@host}/projects.json"
    a = JSON.parse(a, symbolize_names: true)
    a.each do |project|
        sleep(1)
        id = project[:_id]
        puts "removing existing project id: #{id}"
        begin
            RestClient.delete "http://#{@host}/projects/#{id}"
        rescue RestClient::ExceptionWithResponse => err
            case err.http_code
            when 301, 302, 307
                puts '   redirecting after delete'
            end
        end
    end
    
    # setup expected results
    lhs = [{electricity_consumption_cvrmse: 45.33524,
            electricity_consumption_nmbe: -46.72575,
            natural_gas_consumption_cvrmse: 93.87523,
            natural_gas_consumption_nmbe: -76.99358
           },
           {
            electricity_consumption_cvrmse: 37.1028,
            electricity_consumption_nmbe: 36.83981,
            natural_gas_consumption_cvrmse: 26.05441,
            natural_gas_consumption_nmbe: -1.97495
           },
           {
            electricity_consumption_cvrmse: 87.31084,
            electricity_consumption_nmbe: -89.3516,
            natural_gas_consumption_cvrmse: 59.58792,
            natural_gas_consumption_nmbe: 37.55463
           },
           # OpenStudio 3.10.0 results
           {
            electricity_consumption_cvrmse: 45.748727859310684,
            electricity_consumption_nmbe: -47.15331592,
            natural_gas_consumption_cvrmse: 93.87522319797985,
            natural_gas_consumption_nmbe: -76.99356458
           },
           {
            electricity_consumption_cvrmse: 36.992082716685594,
            electricity_consumption_nmbe: 36.75558058301333,
            natural_gas_consumption_cvrmse: 26.054394017956753,
            natural_gas_consumption_nmbe: -1.974857387
           },
           {
            electricity_consumption_cvrmse: 88.15691010253096,
            electricity_consumption_nmbe: -90.09381264,
            natural_gas_consumption_cvrmse: 59.5879904,
            natural_gas_consumption_nmbe: 37.55474192165185
           }]
    
    # setup bad results
    lhs_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]
    statuses = ['tmp', 'tmp','tmp']
    analyses_ids = []
    for i in 0..2 do
      # run an analysis
      command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_sleep_odd.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a lhs"
      puts "run command: #{command}"
      run_analysis = system(command)
      expect(run_analysis).to be true

      a = RestClient.get "http://#{@host}/analyses.json"
      a = JSON.parse(a, symbolize_names: true)
      a = a.sort { |x, y| x[:created_at] <=> y[:created_at] }.reverse
      expect(a).not_to be_empty
      analysis = a[0]
      analysis_id = analysis[:_id]
      analyses_ids << analysis_id
      puts "analyses_ids: #{analyses_ids}, analysis_id: #{analysis_id}"
    end
    status = 'queued'
    timeout_seconds = 360
    sleep 10
    begin
      ::Timeout.timeout(timeout_seconds) do
        # get the analysis pages
        get_count = 0
        get_count_max = 50
        
        until statuses.all? { |status| status == 'completed' }
          begin
            for i in 0..2 do
                a = RestClient.get "http://#{@host}/analyses/#{analyses_ids[i]}/status.json"
                a = JSON.parse(a, symbolize_names: true)
                analysis_type = a[:analysis][:analysis_type]
                expect(analysis_type).to eq('batch_run')

                # analysis_type = a[:analysis][:jobs][0][:analysis_type]
                # expect(analysis_type).to eq('lhs')

                statuses[i] = a[:analysis][:status]
                expect(status).not_to be_nil
                puts "Accessed pages for analysis: #{analyses_ids[i]}, analysis_type: #{analysis_type}, status: #{statuses[i]}"
                
             end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
            get_count += 1 # Increment the retry counter
            retry if get_count <= get_count_max
          end
          puts ''
          sleep 10
        end
      end
    rescue ::Timeout::Error
      puts "Analysis status is `#{statuses}` after #{timeout_seconds} seconds; assuming error."
    end
    expect(statuses.all? { |status| status == 'completed' }).to be true

    get_count = 0
    get_count_max = 50
    begin
      # confirm that datapoints ran successfully
      dps = RestClient.get "http://#{@host}/data_points.json"
      dps = JSON.parse(dps, symbolize_names: true)
      expect(dps).not_to be_nil

      data_points = []
      dps.each do |data_point|
        if analyses_ids.include?(data_point[:analysis_id])
          data_points << data_point
        end
      end
      expect(data_points.size).to eq(9)

      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(2) }
        puts "lhs sim: #{sim}"
        tmp = []
        lhs.each do |x|
          tmp << x.transform_values { |y| y.truncate(2) }
        end
        compare = tmp.include?(sim)
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] compare is: #{compare}"

        compare = lhs_bad.include?(sim)
        expect(compare).to be false
      end
    rescue RestClient::ExceptionWithResponse => e
      puts "rescue: #{e} get_count: #{get_count}"
      sleep Random.new.rand(1.0..10.0)
      retry if get_count <= get_count_max
    end
    
    puts 'check logs for mongo index errors'
    a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/debug_log"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.body).not_to include "OperationFailure"
    expect(a.body).not_to include "FATAL"
    expect(a.body).to include "Created indexes"
    
  end # 3x lhs

end
