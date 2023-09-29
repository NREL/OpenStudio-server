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
RSpec.describe 'RunAlgorithms', type: :feature, algo: true do
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

  it 'run cli_test with bad -z arg', :cli_error, js: true do
    # setup expected results
    # run an analysis
    # test_zip.zip is ../test_zip/test_zip.zip from test.json location and not /test_zip/test_zip.zip
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/test_dir/test.json' 'http://#{@host}' -z '/test_zip/test_zip.zip' -a nsga_nrel"
    puts "run command: #{command}"
    run_analysis = system(command)
    expect(run_analysis).to be false
  end # cli_error

  it 'run cli_test with -z arg', :cli_test, js: true do
    # setup expected results
    nsga_nrel = [
      { electricity_consumption_cvrmse: 21.99399984,
        electricity_consumption_nmbe: 21.36188374,
        natural_gas_consumption_cvrmse: 82.62358861,
        natural_gas_consumption_nmbe: 56.31532858},
      { electricity_consumption_cvrmse: 26.32334162,
        electricity_consumption_nmbe: 25.76504121,
        natural_gas_consumption_cvrmse: 77.98495089,
        natural_gas_consumption_nmbe: 52.28036902},
      { electricity_consumption_cvrmse: 20.41220945,
        electricity_consumption_nmbe: 19.59546222,
        natural_gas_consumption_cvrmse: 75.7459088,
        natural_gas_consumption_nmbe: 50.54773457},
      { electricity_consumption_cvrmse: 82.37755811,
        electricity_consumption_nmbe: -85.31078152,
        natural_gas_consumption_cvrmse: 42.71464426,
        natural_gas_consumption_nmbe: 20.40156665}
    ]
    # setup bad results
    nsga_nrel_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]
    # run an analysis
    # test_zip.zip is ../test_zip/test_zip.zip from test.json location
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/test_dir/test.json' 'http://#{@host}' -z '../test_zip/test_zip.zip' -a nsga_nrel"
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
    begin
      ::Timeout.timeout(timeout_seconds) do
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
          begin
            a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/status.json"
            a = JSON.parse(a, symbolize_names: true)
            analysis_type = a[:analysis][:analysis_type]
            expect(analysis_type).to eq('nsga_nrel')

            status = a[:analysis][:status]
            expect(status).not_to be_nil
            puts "Accessed pages for analysis: #{analysis_id}, analysis_type: #{analysis_type}, status: #{status}"
            jobs = a[:analysis][:jobs]
            puts "jobs: #{jobs}"

            a = RestClient.get "http://#{@host}/analyses/#{analysis_id}.json"
            a = JSON.parse(a, symbolize_names: true)
            status_message = a[:analysis][:status_message]
            puts "status_message: #{status_message}"

            # get all data points in this analysis
            a = RestClient.get "http://#{@host}/data_points.json"
            a = JSON.parse(a, symbolize_names: true)
            data_points = []
            a.each do |data_point|
              if data_point[:analysis_id] == analysis_id
                data_points << data_point
              end
            end
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
            end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
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
      expect(data_points.size).to eq(4)

      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
        puts "nsga sim: #{sim}"
        tmp = []
        nsga_nrel.each do |x|
          tmp << x.transform_values { |y| y.truncate(4) }
        end
        compare = tmp.include?(sim)
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] compare is: #{compare}"

        compare = nsga_nrel_bad.include?(sim)
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
    
  end # cli_test

  it 'run spea_nrel analysis', :spea_nrel, js: true do
    # setup expected results
    spea_nrel = [
      { electricity_consumption_cvrmse: 82.37755811,
        electricity_consumption_nmbe: -85.31078152,
        natural_gas_consumption_cvrmse: 42.71464426,
        natural_gas_consumption_nmbe: 20.40156665},
      { electricity_consumption_cvrmse: 20.41220945,
        electricity_consumption_nmbe: 19.59546222,
        natural_gas_consumption_cvrmse: 75.7459088,
        natural_gas_consumption_nmbe: 50.54773457}
    ]
    # setup bad results
    spea_nrel_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]

    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_calibration_SPEA_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a spea_nrel"
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
    begin
      ::Timeout.timeout(timeout_seconds) do
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
          begin
            a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/status.json"
            a = JSON.parse(a, symbolize_names: true)
            analysis_type = a[:analysis][:analysis_type]
            expect(analysis_type).to eq('spea_nrel')

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
            end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
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
      expect(data_points.size).to eq(2)

      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
        puts "spea sim: #{sim}"
        tmp = []
        spea_nrel.each do |x|
          tmp << x.transform_values { |y| y.truncate(4) }
        end
        compare = tmp.include?(sim)
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] compare is: #{compare}"

        compare = spea_nrel_bad.include?(sim)
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
    
  end # spea_nrel

  it 'run pso analysis', :pso, js: true do
    # setup expected results
    pso = [
      { electricity_consumption_cvrmse: 7.842961959,
        electricity_consumption_nmbe: 4.825488946,
        natural_gas_consumption_cvrmse: 65.8426543,
        natural_gas_consumption_nmbe: -50.77395304},
      { electricity_consumption_cvrmse: 43.65784398,
        electricity_consumption_nmbe: -44.63306507,
        natural_gas_consumption_cvrmse: 108.1024748,
        natural_gas_consumption_nmbe: 77.35386732}
    ]
    # setup bad results
    pso_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]

    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_calibration_PSO_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a pso"
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
    begin
      ::Timeout.timeout(timeout_seconds) do
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
          begin
            a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/status.json"
            a = JSON.parse(a, symbolize_names: true)
            analysis_type = a[:analysis][:analysis_type]
            expect(analysis_type).to eq('pso')

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
            end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
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
      expect(data_points.size).to eq(2)

      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
        puts "pso sim: #{sim}"
        tmp = []
        pso.each do |x|
          tmp << x.transform_values { |y| y.truncate(4) }
        end
        compare = tmp.include?(sim)
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] compare is: #{compare}"

        compare = pso_bad.include?(sim)
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
    
  end # pso

  it 'run rgenoud analysis', :rgenoud, js: true do
    # setup expected results
    rgenoud = [
      { electricity_consumption_cvrmse: 35.76759504,
        electricity_consumption_nmbe: -36.4183773,
        natural_gas_consumption_cvrmse: 50.79722897,
        natural_gas_consumption_nmbe: 27.75592343},
      { electricity_consumption_cvrmse: 74.01069303,
        electricity_consumption_nmbe: -76.73841103,
        natural_gas_consumption_cvrmse: 48.06306663,
        natural_gas_consumption_nmbe: -31.81675554}
    ]
    
    # setup bad results
    rgenoud_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]

    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_calibration_Rgenoud_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a rgenoud"
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
    begin
      ::Timeout.timeout(timeout_seconds) do
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
          begin
            a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/status.json"
            a = JSON.parse(a, symbolize_names: true)
            analysis_type = a[:analysis][:analysis_type]
            expect(analysis_type).to eq('rgenoud')

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
            end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
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
      expect(data_points.size).to eq(2)

      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
        puts "rgenoud sim: #{sim}"
        tmp = []
        rgenoud.each do |x|
          tmp << x.transform_values { |y| y.truncate(4) }
        end
        compare = tmp.include?(sim)
        puts "data_point[:#{data_point[:_id]}] compare is: #{compare}"
        expect(compare).to be true

        compare = rgenoud_bad.include?(sim)
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
    
  end # rgenoud

  it 'run sobol analysis', :sobol, js: true do
    # setup expected results
    sobol = [
      { electricity_consumption_cvrmse: 54.76930032,
        electricity_consumption_nmbe: -56.64433589,
        natural_gas_consumption_cvrmse: 81.93351905,
        natural_gas_consumption_nmbe: -63.94250223},
      { electricity_consumption_cvrmse: 22.94209592,
        electricity_consumption_nmbe: 21.67972075,
        natural_gas_consumption_cvrmse: 26.192299,
        natural_gas_consumption_nmbe: -2.685885302},
      { electricity_consumption_cvrmse: 54.54753494,
        electricity_consumption_nmbe: -56.41041953,
        natural_gas_consumption_cvrmse: 82.12635415,
        natural_gas_consumption_nmbe: -64.11401884},
      { electricity_consumption_cvrmse: 17.03726982,
        electricity_consumption_nmbe: -15.4255319,
        natural_gas_consumption_cvrmse: 44.21297821,
        natural_gas_consumption_nmbe: 22.98843441},
      { electricity_consumption_cvrmse: 18.81466341,
        electricity_consumption_nmbe: -17.63846503,
        natural_gas_consumption_cvrmse: 30.78869741,
        natural_gas_consumption_nmbe: -15.6663694},
      { electricity_consumption_cvrmse: 56.75272836,
        electricity_consumption_nmbe: -58.74745506,
        natural_gas_consumption_cvrmse: 108.2431218,
        natural_gas_consumption_nmbe:  -85.94476756}
    ] 
    
    # setup bad results
    sobol_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]

    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_Sobol_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a sobol"
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
    begin
      ::Timeout.timeout(timeout_seconds) do
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
          begin
            a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/status.json"
            a = JSON.parse(a, symbolize_names: true)
            analysis_type = a[:analysis][:analysis_type]
            expect(analysis_type).to eq('sobol')

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
            end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
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
        sim = sim.transform_values { |x| x.truncate(4) }
        puts "sobol sim: #{sim}"
        tmp = []
        sobol.each do |x|
          tmp << x.transform_values { |y| y.truncate(4) }
        end
        compare = tmp.include?(sim)
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] compare is: #{compare}"

        compare = sobol_bad.include?(sim)
        expect(compare).to be false
      end
    rescue RestClient::ExceptionWithResponse => e
      puts "rescue: #{e} get_count: #{get_count}"
      sleep Random.new.rand(1.0..10.0)
      retry if get_count <= get_count_max
    end
    
    puts "expect Sobol Algorithm results to be success"
    a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/download_algorithm_results_zip"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("application/zip")
    expect(a.size).to be >(30000)
    expect(a.size).to be <(40000)
    
    puts 'check logs for mongo index errors'
    a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/debug_log"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.body).not_to include "OperationFailure"
    expect(a.body).not_to include "FATAL"
    expect(a.body).to include "Created indexes"
    
  end # sobol

  it 'run lhs analysis', :lhs, js: true do
    # setup expected results
    lhs = [
      { electricity_consumption_cvrmse: 25.57415623,
        electricity_consumption_nmbe: 25.27266717,
        natural_gas_consumption_cvrmse: 112.9275503,
        natural_gas_consumption_nmbe: 80.53613285},
      { electricity_consumption_cvrmse: 91.61355274,
        electricity_consumption_nmbe: -94.87047784,
        natural_gas_consumption_cvrmse: 42.93786686,
        natural_gas_consumption_nmbe: -23.69726679}
    ]
    
    # setup bad results
    lhs_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]

    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_LHS_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a lhs"
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
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
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
            end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
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
      expect(data_points.size).to eq(2)

      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
        puts "lhs sim: #{sim}"
        tmp = []
        lhs.each do |x|
          tmp << x.transform_values { |y| y.truncate(4) }
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
    
  end # lhs

  it 'run lhs_discrete analysis', :lhs_discrete, js: true do
    # setup expected results
    lhs = [
      { electricity_consumption_cvrmse: 38.01508752,
        electricity_consumption_nmbe: -38.93208252,
        natural_gas_consumption_cvrmse: 206.5584047,
        natural_gas_consumption_nmbe: -166.2205646},
      { electricity_consumption_cvrmse: 37.63173269,
        electricity_consumption_nmbe: -38.54754034,
        natural_gas_consumption_cvrmse: 206.578935,
        natural_gas_consumption_nmbe: -166.233957},
      { electricity_consumption_cvrmse: 37.63173269,
        electricity_consumption_nmbe: -38.54754034,
        natural_gas_consumption_cvrmse: 150.9769767,
        natural_gas_consumption_nmbe: -122.6180691}
    ]
    
    # setup bad results
    lhs_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]

    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_LHS_2013_discrete.json' 'http://#{@host}' -a lhs"
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
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
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
            end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
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
      expect(data_points.size).to eq(3)

      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
        puts "lhs discrete sim: #{sim}"
        tmp = []
        lhs.each do |x|
          tmp << x.transform_values { |y| y.truncate(4) }
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
    
  end # lhs_discrete

  it 'run morris analysis', :morris, js: true do
    # setup expected results
    morris = [
      { electricity_consumption_cvrmse: 89.83993479,
        electricity_consumption_nmbe: -93.43862965,
        natural_gas_consumption_cvrmse: 83.61530554,
        natural_gas_consumption_nmbe: -63.94874443},
      { electricity_consumption_cvrmse: 87.52372524,
        electricity_consumption_nmbe: -90.98340992,
        natural_gas_consumption_cvrmse: 42.78515488,
        natural_gas_consumption_nmbe: -25.6420468},
      { electricity_consumption_cvrmse: 23.52940388,
        electricity_consumption_nmbe: 22.1736249,
        natural_gas_consumption_cvrmse: 136.7394956,
        natural_gas_consumption_nmbe: -113.1026692}
    ]  
    
    # setup bad results
    morris_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]

    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_Morris_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a morris"
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
    begin
      ::Timeout.timeout(timeout_seconds) do
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
          begin
            a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/status.json"
            a = JSON.parse(a, symbolize_names: true)
            analysis_type = a[:analysis][:analysis_type]
            expect(analysis_type).to eq('morris')

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
            end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
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
      expect(data_points.size).to eq(3)

      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
        puts "morris sim: #{sim}"
        tmp = []
        morris.each do |x|
          tmp << x.transform_values { |y| y.truncate(4) }
        end
        compare = tmp.include?(sim)
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] compare is: #{compare}"

        compare = morris_bad.include?(sim)
        expect(compare).to be false
      end
    rescue RestClient::ExceptionWithResponse => e
      puts "rescue: #{e} get_count: #{get_count}"
      sleep Random.new.rand(1.0..10.0)
      retry if get_count <= get_count_max
    end
    
    puts "expect Morris Algorithm results to be success"
    a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/download_algorithm_results_zip"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("application/zip")
    expect(a.size).to be >(170000)
    expect(a.size).to be <(200000)
    
    puts 'check logs for mongo index errors'
    a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/debug_log"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.body).not_to include "OperationFailure"
    expect(a.body).not_to include "FATAL"
    expect(a.body).to include "Created indexes"
    
  end # morris
  
  it 'run single_run analysis', :single_run, js: true do
    # setup expected results
    single_run = [
      {  electricity_consumption_cvrmse: 34.85459811,
         electricity_consumption_nmbe: -35.59102141,
         natural_gas_consumption_cvrmse: 162.9418784,
         natural_gas_consumption_nmbe: -130.5833959}
     ] 
    # setup bad results
    single_run_bad = [
      { electricity_consumption_cvrmse: 0,
        electricity_consumption_nmbe: 0,
        natural_gas_consumption_cvrmse: 0,
        natural_gas_consumption_nmbe: 0 }
    ]

    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_calibration_single_run_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a single_run"
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
    begin
      ::Timeout.timeout(timeout_seconds) do
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
          begin
            a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/status.json"
            a = JSON.parse(a, symbolize_names: true)
            analysis_type = a[:analysis][:analysis_type]
            expect(analysis_type).to eq('batch_run')

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
            end
          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep Random.new.rand(1.0..10.0)
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
      expect(data_points.size).to eq(1)

      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
        puts "single_run sim: #{sim}"
        tmp = []
        single_run.each do |x|
          tmp << x.transform_values { |y| y.truncate(4) }
        end
        compare = tmp.include?(sim)
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] compare is: #{compare}"

        compare = single_run_bad.include?(sim)
        expect(compare).to be false
        
        a = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}/download_result_file?filename=calibration_reports_enhanced_20_report_xml_file.xml"
        expect(a).not_to be_empty
        #expect(a.size).to be >(1000)
        #expect(a.size).to be <(2000)
        expect(a.headers[:status]).to eq("200 OK")
        expect(a.headers[:content_type]).to eq("application/xml")
        expect(a.headers[:content_disposition]).to include("calibration_reports_enhanced_20_report_xml_file.xml")
      end
    rescue RestClient::ExceptionWithResponse => e
      if e.http_code == 422
        # Handle the 422 Unprocessable Entity error here if .xml file not found
        fail("Received a 422 error: calibration_reports_enhanced_20_report_xml_file.xml not avail for download")
      else
        puts "rescue: #{e} get_count: #{get_count}"
        sleep Random.new.rand(1.0..10.0)
        get_count = get_count + 1
        retry if get_count <= get_count_max
      end
    end
    
    puts 'check logs for mongo index errors'
    a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/debug_log"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.body).not_to include "OperationFailure"
    expect(a.body).not_to include "FATAL"
    expect(a.body).to include "Created indexes"
    
  end # single_run
end
