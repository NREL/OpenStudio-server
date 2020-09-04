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
ruby_cmd = 'ruby'
meta_cli = File.absolute_path('/opt/openstudio/bin/openstudio_meta')
project = File.absolute_path(File.join(File.dirname(__FILE__), '../files/'))
#host = '127.0.0.1'
cmd = 'docker ps'
out = system(cmd)
puts "docker ps: #{out.to_s}"

# the actual tests
RSpec.describe 'RunAlgorithms', type: :feature, depends_resque: true do
  #before :all do
  #  @previous_job_manager = Rails.application.config.job_manager
  #  Rails.application.config.job_manager = :resque
  
    #gem install
    #command = "#{ruby_cmd} #{meta_cli} install_gems"
    #puts command
    #run_analysis = system(command)
    #expect(run_analysis).to be true
  #end
  
  #after :all do
  #  Rails.application.config.job_manager = @previous_job_manager
  #end

  before do
    # Look at DatabaseCleaner gem in the future to deal with this.
    #begin
    #  Project.destroy_all
    #  Delayed::Job.destroy_all
    #rescue Errno::EACCES => e
    #  puts 'Cannot unlink files, will try and continue'
    #end

    #Resque.workers.each(&:unregister_worker)
    #Resque.queues.each { |q| Resque.redis.del "queue:#{q}" }

    @host = "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    puts "App host is: http://#{@host}"

    # TODO: Make this a helper of some sort
    options = { hostname: "http://#{@host}" }
    # TODO: Convert this over to the openstudio_meta
    #@api = OpenStudio::Analysis::ServerApi.new(options)
    APP_CONFIG['os_server_host_url'] = options[:hostname]
  end

  it 'run cli_test with bad -z arg', :cli_error, js: true do
    #setup expected results
    # run an analysis
    # test_zip.zip is ../test_zip/test_zip.zip from test.json location and not /test_zip/test_zip.zip
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/test_dir/test.json' 'http://#{@host}' -z '/test_zip/test_zip.zip' -a nsga_nrel"
    puts "run command: #{command}"
    run_analysis = system(command)
    expect(run_analysis).to be false
   
  end #cli_error
  
  it 'run cli_test with -z arg', :cli_test, js: true do
    #setup expected results
    nsga_nrel = [
    {:electricity_consumption_cvrmse => 21.8917,
     :electricity_consumption_nmbe => 21.2198,
     :natural_gas_consumption_cvrmse => 74.0377,
     :natural_gas_consumption_nmbe => 48.7487},
    {:electricity_consumption_cvrmse => 81.1799,
     :electricity_consumption_nmbe => -84.0936,
     :natural_gas_consumption_cvrmse => 44.4995,
     :natural_gas_consumption_nmbe => 22.6094},
    {:electricity_consumption_cvrmse => 27.5972,
     :electricity_consumption_nmbe => 27.0657,
     :natural_gas_consumption_cvrmse => 76.8553,
     :natural_gas_consumption_nmbe => 51.0137},
    {:electricity_consumption_cvrmse => 23.7873,
     :electricity_consumption_nmbe => 23.2828,
     :natural_gas_consumption_cvrmse => 81.4910,
     :natural_gas_consumption_nmbe => 55.1189}
    ]
    #setup bad results
    nsga_nrel_bad = [
     {:electricity_consumption_cvrmse => 0,
      :electricity_consumption_nmbe => 0,
      :natural_gas_consumption_cvrmse => 0,
      :natural_gas_consumption_nmbe => 0}
    ]
    # run an analysis
    # test_zip.zip is ../test_zip/test_zip.zip from test.json location
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/test_dir/test.json' 'http://#{@host}' -z '../test_zip/test_zip.zip' -a nsga_nrel"
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
    timeout_seconds = 120
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
            puts "jobs: #{jobs.to_s}"
            
            a = RestClient.get "http://#{@host}/analyses/#{analysis_id}.json"
            a = JSON.parse(a, symbolize_names: true)
            status_message = a[:analysis][:status_message]
            puts "status_message: #{status_message.to_s}"

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
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
      
        compare = nsga_nrel.include?(sim)
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
  end #cli_test
  
  it 'run nsga_nrel analysis', :nsga_nrel, js: true do
    #setup expected results
    nsga_nrel = [
    {:electricity_consumption_cvrmse => 21.8917,
     :electricity_consumption_nmbe => 21.2198,
     :natural_gas_consumption_cvrmse => 74.0377,
     :natural_gas_consumption_nmbe => 48.7487},
    {:electricity_consumption_cvrmse => 81.1799,
     :electricity_consumption_nmbe => -84.0936,
     :natural_gas_consumption_cvrmse => 44.4995,
     :natural_gas_consumption_nmbe => 22.6094},
    {:electricity_consumption_cvrmse => 27.5972,
     :electricity_consumption_nmbe => 27.0657,
     :natural_gas_consumption_cvrmse => 76.8553,
     :natural_gas_consumption_nmbe => 51.0137},
    {:electricity_consumption_cvrmse => 23.7873,
     :electricity_consumption_nmbe => 23.2828,
     :natural_gas_consumption_cvrmse => 81.4910,
     :natural_gas_consumption_nmbe => 55.1189}
    ]
    #setup bad results
    nsga_nrel_bad = [
     {:electricity_consumption_cvrmse => 0,
      :electricity_consumption_nmbe => 0,
      :natural_gas_consumption_cvrmse => 0,
      :natural_gas_consumption_nmbe => 0}
    ]

    # run an analysis
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/SEB_calibration_NSGA_2013.json' 'http://#{@host}' -a nsga_nrel"
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
    timeout_seconds = 120
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
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
      
        compare = nsga_nrel.include?(sim)
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
  end #nsga_nrel

  it 'run nsga_nrel_z analysis', :nsga_nrel_z, js: true do
    #setup expected results
    nsga_nrel = [
    {:electricity_consumption_cvrmse => 21.8917,
     :electricity_consumption_nmbe => 21.2198,
     :natural_gas_consumption_cvrmse => 74.0377,
     :natural_gas_consumption_nmbe => 48.7487},
    {:electricity_consumption_cvrmse => 81.1799,
     :electricity_consumption_nmbe => -84.0936,
     :natural_gas_consumption_cvrmse => 44.4995,
     :natural_gas_consumption_nmbe => 22.6094},
    {:electricity_consumption_cvrmse => 27.5972,
     :electricity_consumption_nmbe => 27.0657,
     :natural_gas_consumption_cvrmse => 76.8553,
     :natural_gas_consumption_nmbe => 51.0137},
    {:electricity_consumption_cvrmse => 23.7873,
     :electricity_consumption_nmbe => 23.2828,
     :natural_gas_consumption_cvrmse => 81.4910,
     :natural_gas_consumption_nmbe => 55.1189}
    ]
    #setup bad results
    nsga_nrel_bad = [
     {:electricity_consumption_cvrmse => 0,
      :electricity_consumption_nmbe => 0,
      :natural_gas_consumption_cvrmse => 0,
      :natural_gas_consumption_nmbe => 0}
    ]

    # run an analysis
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/SEB_calibration_NSGA_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a nsga_nrel"
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
    timeout_seconds = 120
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
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
      
        compare = nsga_nrel.include?(sim)
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
  end #nsga_nrel_z
  
  it 'run spea_nrel analysis', :spea_nrel, js: true do
    #setup expected results
    spea_nrel = [
    {:electricity_consumption_cvrmse => 81.1799,
     :electricity_consumption_nmbe => -84.0936,
     :natural_gas_consumption_cvrmse => 44.4995,
     :natural_gas_consumption_nmbe => 22.6094},
    {:electricity_consumption_cvrmse => 21.8917,
     :electricity_consumption_nmbe => 21.2198,
     :natural_gas_consumption_cvrmse => 74.0377,
     :natural_gas_consumption_nmbe => 48.7487}
    ]
    #setup bad results
    spea_nrel_bad = [
     {:electricity_consumption_cvrmse => 0,
      :electricity_consumption_nmbe => 0,
      :natural_gas_consumption_cvrmse => 0,
      :natural_gas_consumption_nmbe => 0}
    ]

    # run an analysis
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/SEB_calibration_SPEA_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a spea_nrel"
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
    timeout_seconds = 120
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
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
      
        compare = spea_nrel.include?(sim)
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
  end #spea_nrel
  
  it 'run pso analysis', :pso, js: true do
    #setup expected results
    pso = [
    {:electricity_consumption_cvrmse => 8.5655,
     :electricity_consumption_nmbe => 5.9796,
     :natural_gas_consumption_cvrmse => 65.1321,
     :natural_gas_consumption_nmbe => -50.6434},
     {:electricity_consumption_cvrmse => 41.6907,
      :electricity_consumption_nmbe => -42.5526,
      :natural_gas_consumption_cvrmse => 108.0013,
      :natural_gas_consumption_nmbe => 77.2449}
    ]
    #setup bad results
    pso_bad = [
    {:electricity_consumption_cvrmse => 0,
     :electricity_consumption_nmbe => 0,
     :natural_gas_consumption_cvrmse => 0,
     :natural_gas_consumption_nmbe => 0}
    ]

    # run an analysis
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/SEB_calibration_PSO_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a pso"
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
    timeout_seconds = 120
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
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
      
        compare = pso.include?(sim)
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
  end #pso
  
  it 'run rgenoud analysis', :rgenoud, js: true do
    #setup expected results
    rgenoud = [
    {:electricity_consumption_cvrmse => 31.1268,
     :electricity_consumption_nmbe => -31.6654,
     :natural_gas_consumption_cvrmse => 29.6280,
     :natural_gas_consumption_nmbe => -10.4302},
    {:electricity_consumption_cvrmse => 58.2150,
     :electricity_consumption_nmbe => -59.7658,
     :natural_gas_consumption_cvrmse => 157.5567,
     :natural_gas_consumption_nmbe => -129.7941}
    ]
    #setup bad results
    rgenoud_bad = [
     {:electricity_consumption_cvrmse => 0,
      :electricity_consumption_nmbe => 0,
      :natural_gas_consumption_cvrmse => 0,
      :natural_gas_consumption_nmbe => 0}
    ]

    # run an analysis
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/SEB_calibration_Rgenoud_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a rgenoud"
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
    timeout_seconds = 120
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
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
      
        compare = rgenoud.include?(sim)
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] compare is: #{compare}"

        compare = rgenoud_bad.include?(sim)
        expect(compare).to be false
      end
    rescue RestClient::ExceptionWithResponse => e
      puts "rescue: #{e} get_count: #{get_count}"
      sleep Random.new.rand(1.0..10.0)
      retry if get_count <= get_count_max
    end    
  end #rgenoud

  it 'run sobol analysis', :sobol, js: true do
    #setup expected results
    sobol = [
    {:electricity_consumption_cvrmse => 42.9103,
     :electricity_consumption_nmbe => -44.0163,
     :natural_gas_consumption_cvrmse => 28.8360,
     :natural_gas_consumption_nmbe => -0.0566},
    {:electricity_consumption_cvrmse => 16.6939,
     :electricity_consumption_nmbe => 14.0761,
     :natural_gas_consumption_cvrmse => 113.9346,
     :natural_gas_consumption_nmbe => -94.2536},
     {:electricity_consumption_cvrmse => 20.9054,
     :electricity_consumption_nmbe => 19.2165,
     :natural_gas_consumption_cvrmse => 58.8637,
     :natural_gas_consumption_nmbe => -47.3409}
    ]
    #setup bad results
    sobol_bad = [
     {:electricity_consumption_cvrmse => 0,
      :electricity_consumption_nmbe => 0,
      :natural_gas_consumption_cvrmse => 0,
      :natural_gas_consumption_nmbe => 0}
    ]

    # run an analysis
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/SEB_Sobol_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a sobol"
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
    timeout_seconds = 120
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
      expect(data_points.size).to eq(3)
    
      data_points.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')
      
        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
      
        compare = sobol.include?(sim)
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
  end #sobol

  it 'run lhs analysis', :lhs, js: true do
    #setup expected results
    lhs = [
    {:electricity_consumption_cvrmse => 26.8357,
     :electricity_consumption_nmbe => 26.5679,
     :natural_gas_consumption_cvrmse => 112.0244,
     :natural_gas_consumption_nmbe => 79.8094},
    {:electricity_consumption_cvrmse => 90.0408,
     :electricity_consumption_nmbe => -93.2786,
     :natural_gas_consumption_cvrmse => 40.2817,
     :natural_gas_consumption_nmbe => -21.1406}
    ]
    #setup bad results
    lhs_bad = [
     {:electricity_consumption_cvrmse => 0,
      :electricity_consumption_nmbe => 0,
      :natural_gas_consumption_cvrmse => 0,
      :natural_gas_consumption_nmbe => 0}
    ]

    # run an analysis
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/SEB_LHS_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a lhs"
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
    timeout_seconds = 120
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
            
            #analysis_type = a[:analysis][:jobs][0][:analysis_type]
            #expect(analysis_type).to eq('lhs')
          
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
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
      
        compare = lhs.include?(sim)
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
  end #lhs

  it 'run lhs_discrete analysis', :lhs_discrete, js: true do
    #setup expected results
    lhs = [
    {:electricity_consumption_cvrmse => 37.0121,
     :electricity_consumption_nmbe => -37.8209,
     :natural_gas_consumption_cvrmse => 202.5293,
     :natural_gas_consumption_nmbe => -163.6007},
    {:electricity_consumption_cvrmse => 36.6346,
     :electricity_consumption_nmbe => -37.4445,
     :natural_gas_consumption_cvrmse => 202.5468,
     :natural_gas_consumption_nmbe => -163.6121},
    {:electricity_consumption_cvrmse => 36.6346,
     :electricity_consumption_nmbe => -37.4445,
     :natural_gas_consumption_cvrmse => 147.6364,
     :natural_gas_consumption_nmbe => -120.4101}
    ]
    #setup bad results
    lhs_bad = [
     {:electricity_consumption_cvrmse => 0,
      :electricity_consumption_nmbe => 0,
      :natural_gas_consumption_cvrmse => 0,
      :natural_gas_consumption_nmbe => 0}
    ]

    # run an analysis
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/SEB_LHS_2013_discrete.json' 'http://#{@host}' -a lhs"
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
    timeout_seconds = 120
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
            
            #analysis_type = a[:analysis][:jobs][0][:analysis_type]
            #expect(analysis_type).to eq('lhs')
          
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
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
      
        compare = lhs.include?(sim)
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
  end #lhs_discrete
  
  it 'run morris analysis', :morris, js: true do
    #setup expected results
    morris = [
    {:electricity_consumption_cvrmse => 24.4905,
     :electricity_consumption_nmbe => 23.1731,
     :natural_gas_consumption_cvrmse => 133.9203,
     :natural_gas_consumption_nmbe => -111.3358},
    {:electricity_consumption_cvrmse => 86.3250,
     :electricity_consumption_nmbe => -89.7282,
     :natural_gas_consumption_cvrmse => 40.6764,
     :natural_gas_consumption_nmbe => -23.7675},
     {:electricity_consumption_cvrmse => 88.8407,
     :electricity_consumption_nmbe => -92.3903,
     :natural_gas_consumption_cvrmse =>	81.0866,
     :natural_gas_consumption_nmbe => -62.2454}
    ]
    #setup bad results
    morris_bad = [
     {:electricity_consumption_cvrmse => 0,
      :electricity_consumption_nmbe => 0,
      :natural_gas_consumption_cvrmse => 0,
      :natural_gas_consumption_nmbe => 0}
    ]

    # run an analysis
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/SEB_Morris_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a morris"
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
    timeout_seconds = 120
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
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
      
        compare = morris.include?(sim)
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
  end #morris
  
end

