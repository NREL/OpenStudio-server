# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
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

#################################################################################
# To Run this test manually:
#
#   start a server stack with /spec added and ssh into the Web container
#   >ruby /opt/openstudio/bin/openstudio_meta install_gems
#   >cd /opt/openstudio/spec/
#   >gem install rspec
#   >rspec openstudio_algo_spec.rb
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
    APP_CONFIG['os_server_host_url'] = options[:hostname]
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
      { electricity_consumption_cvrmse: 21.0098, 
        electricity_consumption_nmbe: 20.2345, 
        natural_gas_consumption_cvrmse: 75.7722, 
        natural_gas_consumption_nmbe: 50.3806},
      { electricity_consumption_cvrmse: 82.2784,
        electricity_consumption_nmbe: -85.2081,
        natural_gas_consumption_cvrmse: 45.9709,
        natural_gas_consumption_nmbe: 23.9474 },
      { electricity_consumption_cvrmse: 20.5651,
        electricity_consumption_nmbe: 19.7220,
        natural_gas_consumption_cvrmse: 76.5434,
        natural_gas_consumption_nmbe: 50.8682 },
      { electricity_consumption_cvrmse: 26.5909,
        electricity_consumption_nmbe: 26.0065,
        natural_gas_consumption_cvrmse: 79.2440,
        natural_gas_consumption_nmbe: 53.0177 },
      { electricity_consumption_cvrmse: 22.4652,
        electricity_consumption_nmbe: 21.8327,
        natural_gas_consumption_cvrmse: 83.9825,
        natural_gas_consumption_nmbe: 57.1664 }
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

        compare = nsga_nrel.include?(sim)
        puts sim
        puts "\n\n"
        puts nsga_nrel
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
  end # cli_test

  it 'run spea_nrel analysis', :spea_nrel, js: true do
    # setup expected results
    spea_nrel = [
      { electricity_consumption_cvrmse: 81.9164, 
        electricity_consumption_nmbe: -84.8456, 
        natural_gas_consumption_cvrmse: 42.5082, 
        natural_gas_consumption_nmbe: 20.1261},
      { electricity_consumption_cvrmse: 82.2784,
        electricity_consumption_nmbe: -85.2081,
        natural_gas_consumption_cvrmse: 45.9709,
        natural_gas_consumption_nmbe: 23.9474 },
      { electricity_consumption_cvrmse: 20.5651,
        electricity_consumption_nmbe: 19.7220,
        natural_gas_consumption_cvrmse: 76.5434,
        natural_gas_consumption_nmbe: 50.8682 }
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

        compare = spea_nrel.include?(sim)
        puts sim
        puts "\n\n"
        puts spea_nrel
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
  end # spea_nrel

end
