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
#   >cd /opt/openstudio/server/spec/
#   >gem install rest-client rails_helper json rspec rspec-retry
#   >rspec openstudio_algo_spec.rb
#
#################################################################################

require 'rails_helper'
require 'rest-client'
require 'json'
require 'csv'

# Set obvious paths for start-local & run-analysis invocation
RUBY_CMD = 'ruby'
BUNDLE_CMD = 'bundle exec ruby'

# Docker tests have these hard coded paths
META_CLI = File.absolute_path('/opt/openstudio/bin/openstudio_meta')
PROJECT = File.absolute_path(File.join(File.dirname(__FILE__), '../files/'))
HOST = '127.0.0.1'

puts "Project folder is: #{PROJECT}"
puts "META_CLI is: #{META_CLI}"
puts "App host is: http://#{HOST}"

# the actual tests
RSpec.describe 'TestAPIs', type: :feature do
  before :all do
    @host = HOST
    @project = PROJECT
    @meta_cli = META_CLI
    @ruby_cmd = RUBY_CMD
    @bundle_cmd = BUNDLE_CMD

    options = { hostname: "http://#{@host}" }
  end

  it 'run nginx_tests', :nginx_tests do

    sleep(1)
    puts 'access main GUI page'
    a = RestClient.get "http://#{@host}"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.body).not_to include "Error"
    expect(a.body).to include "OpenStudio Cloud Management Console"
    
    sleep(1)
    puts 'check nginx status'
    a = RestClient.get "http://#{@host}/nginx"
    puts 'expect code 200'
    expect(a.code).to eq(200)
    puts 'expect \'Active connections\' in body'
    compare = a.body.include?('Active connections')
    expect(compare).to be true
    
    puts 'expect user to be \'root\''
    whoami = `whoami`
    puts "whoami: #{whoami}"
    expect(whoami).to eq("root\n")
    
    puts 'test nginx.conf file as user nginx'
    test_config = `su nginx -c 'sudo /opt/nginx/sbin/nginx -t 2>&1'`
    puts "test_config: #{test_config}"
    syntax = test_config.include?('syntax is ok')
    puts 'expect test_config to include \'syntax is ok\''
    expect(syntax).to be true
    successful = test_config.include?('test is successful')
    puts 'expect test_config to include \'test is successful\''
    expect(successful).to be true
    
    sleep(1)
    puts 'get nginx processes'
    nginx_pids = `ps aux|grep nginx`
    expect(nginx_pids).not_to be_empty
    puts 'get nginx PIDs'
    nginx_worker_pids = nginx_pids.split("\n").select{ |s| s =~ /nginx: worker process$/}.map {|e| e[%r{nginx \s*\d+\s}][%r{\d+}]} if !nginx_pids.nil?
    puts "nginx_worker_pids: #{nginx_worker_pids}"
    expect(nginx_worker_pids).not_to be_empty
    
    sleep(1)
    puts 'reload \'nginx.conf\' as user \'nginx\'' 
    `su nginx -c 'sudo /opt/nginx/sbin/nginx -s reload'`
    puts 'wait for 3 seconds'
    sleep(3)
    
    puts 'get nginx processes'
    nginx_pids = `ps aux|grep nginx`
    expect(nginx_pids).not_to be_empty
    puts 'get nginx PIDs'
    nginx_worker_pids2 = nginx_pids.split("\n").select{ |s| s =~ /nginx: worker process$/}.map {|e| e[%r{nginx \s*\d+\s}][%r{\d+}]} if !nginx_pids.nil?
    puts "nginx_worker_pids2: #{nginx_worker_pids2}"
    expect(nginx_worker_pids2).not_to be_empty
    expect(nginx_worker_pids2.is_a?(Array)).to be true
    new_pids = nginx_worker_pids2.is_a?(Array) && !nginx_worker_pids2.any? {|pids| nginx_worker_pids.include?(pids)}
    expect(new_pids).to be true
    
    sleep(1)
    puts 'check nginx status'
    a = RestClient.get "http://#{@host}/nginx"
    puts 'expect code 200'
    expect(a.code).to eq(200)
    puts 'expect \'Active connections\' in body'
    compare = a.body.include?('Active connections')
    expect(compare).to be true
    
    sleep(1)
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
    
    # the tests below submit an analysis and once that queues datapoints
    # it submits another analysis, which will reload nginx while the other
    # analysis is running.  the test expects both analysis to complete all 
    # six datapoints that are successful with objective function values
    
    sleep(1)
    puts 'check there are no projects'
    a = RestClient.get "http://#{@host}/projects.json"
    a = JSON.parse(a, symbolize_names: true)
    expect(a).to be_empty
    
    sleep(1)
    puts 'check that there are no analyses'
    a = RestClient.get "http://#{@host}/analyses.json"
    a = JSON.parse(a, symbolize_names: true)
    expect(a).to be_empty
    
    sleep(1)
    puts 'run a morris analysis'
    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_Morris_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a morris"
    puts "run command: #{command}"
    run_analysis = system(command)
    expect(run_analysis).to be true
    
    sleep(3)
    a = RestClient.get "http://#{@host}/analyses.json"
    a = JSON.parse(a, symbolize_names: true)
    a = a.sort { |x, y| x[:created_at] <=> y[:created_at] }.reverse
    expect(a).not_to be_empty
    analysis = a[0]
    analysis_id = analysis[:_id]
    
    a = RestClient.get "http://#{@host}/analyses/#{analysis_id}/status.json"
    a = JSON.parse(a, symbolize_names: true)
    analysis_type = a[:analysis][:analysis_type]
    expect(analysis_type).to eq('morris')

    status = a[:analysis][:status]
    expect(status).not_to be_nil
    puts "Accessed pages for analysis: #{analysis_id}, analysis_type: #{analysis_type}, status: #{status}"
    
    puts "sleep for 10 seconds"
    sleep(10)
    get_count = 0
    get_count_max = 50
    # get all data points in this analysis
    puts 'make sure datapoints are queued or started'
    begin
        a = RestClient.get "http://#{@host}/data_points.json"
        a = JSON.parse(a, symbolize_names: true)
        data_points = []
        a.each do |data_point|
          if data_point[:analysis_id] == analysis_id
            data_points << data_point
          end
        end
        puts "datapoints: #{data_points}"
        have_datapoints = !data_points.empty?
        puts "have_datapoints: #{have_datapoints}"
        raise if have_datapoints != true
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
    rescue => e
        puts "rescue: #{e} get_count: #{get_count}"
        sleep(10)
        retry if get_count <= get_count_max
        expect(have_datapoints).to be true
    end
    
    puts "have datapoints queued, submit another analysis"
    #submit another job with datapoint started and queued
    #this will reload nginx
    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/SEB_Morris_2013.json' 'http://#{@host}' -z 'SEB_calibration_NSGA_2013' -a morris"
    puts "run command: #{command}"
    run_analysis = system(command)
    expect(run_analysis).to be true
    
    sleep(3)
    a = RestClient.get "http://#{@host}/analyses.json"
    a = JSON.parse(a, symbolize_names: true)
    a = a.sort { |x, y| x[:created_at] <=> y[:created_at] }.reverse
    expect(a).not_to be_empty
    analysis = a[0]
    new_analysis_id = analysis[:_id]
    
    #wait till first analysis completes
    puts "run second analysis"
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

            status = a[:analysis][:status]
            expect(status).not_to be_nil
            puts "Accessed pages for analysis: #{analysis_id}, analysis_type: #{analysis_type}, status: #{status}"

          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep(10.0)
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

    puts "wait for second analysis to complete"
    #wait till second analysis completes
    status = 'queued'
    timeout_seconds = 360
    begin
      ::Timeout.timeout(timeout_seconds) do
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
          begin
            a = RestClient.get "http://#{@host}/analyses/#{new_analysis_id}/status.json"
            a = JSON.parse(a, symbolize_names: true)

            status = a[:analysis][:status]
            expect(status).not_to be_nil
            puts "Accessed pages for analysis: #{new_analysis_id}, analysis_type: #{analysis_type}, status: #{status}"

          rescue RestClient::ExceptionWithResponse => e
            puts "rescue: #{e} get_count: #{get_count}"
            sleep(10.0)
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
    
    puts "expect there to be 6 datapoints"
    dps = RestClient.get "http://#{@host}/data_points.json"
    dps = JSON.parse(dps, symbolize_names: true)
    expect(dps).not_to be_nil
    expect(dps.size).to eq(6)
    
    puts "confirm that all datapoints ran successfully and have objective function values"
    dps.each do |data_point|
        dp = RestClient.get "http://#{@host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')

        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe, :natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
        sim = sim.transform_values { |x| x.truncate(4) }
        sim.values.each do |s|
            is_a_number = s.is_a?(Float)
            expect(is_a_number).to be true
        end        
    end
      
  end    
end
