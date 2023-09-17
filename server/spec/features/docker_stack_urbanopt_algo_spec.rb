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
#   >rspec spec/features/docker_stack_urbanopt_algo_spec.rb
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
RSpec.describe 'RunUrbanOptAlgorithms', type: :feature, algo: true do
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

  it 'run urbanopt_single_run analysis', :single_run, js: true do
    # setup expected results
    single_run = [
      { electricity_kwh: 20983305.555555556,
        natural_gas_kwh: 24483569.444444444 }
    ]

    # setup bad results
    single_run_bad = [
      { electricity_kwh: 0,
        natural_gas_kwh: 0}
    ]

    # run an analysis
    command = "#{@bundle_cmd} #{@meta_cli} run_analysis --debug --verbose '#{@project}/URBANopt_092_sr.json' 'http://#{@host}' -z 'URBANopt_092' -a single_run"
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
    timeout_seconds = 920
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
        data_point_id = data_point[:_id]
        results = dp[:data_point][:results]
        
       # results for UrbanOpt test is of the form: 
       # results: {
       #     7370ee51-7eb4-489c-a1ab-e45ec4f4310f: {
       #     electricity_kwh: 19294572.222222224,
       #     applicable: true
       #     },
       #     314ae231-7de2-4a16-a323-dc12af050293: {
       #     natural_gas_kwh: 21731513.888888888,
       #     applicable: true
       #     },
       #     bda8a75f-13d8-4066-8682-a2d9cb7ecb85: {
       #     electricity_kwh_fans: 455055.5555555556,
       #     applicable: true
       #     },
       #     3675d5a6-de84-469d-b612-3aedc3a56510: {
       #     electricity_kwh_fans: 610758.3333333334,
       #     applicable: true
       #     }
       # }
        
        expect(results).not_to be_nil
        expect(results.size).to eq(4)
        sim_result = {}
        key_array = [ "electricity_kwh", "natural_gas_kwh" ]
        #loop through results to ignore the UUID as the first key, they change values as they take place of measure name which doesnt exist here.
        #get the key value pair for the objective function and not applicable:true
        results.each do |key, result|
          expect(result.keys.size).to eq(2)
          result.each do |r|
            if key_array.include?(r.first.to_s)
              sim_result[r.first.to_sym] = result[r.first.to_sym]
            end
          end  
        end
        sim = sim_result.slice(:electricity_kwh, :natural_gas_kwh)
        expect(sim.size).to eq(2)
        sim = sim.transform_values { |x| x.round(-6) }
        puts "single_run sim: #{sim}"
        tmp = []
        single_run.each do |x|
          tmp << x.transform_values { |y| y.round(-6) }
        end
        compare = tmp.include?(sim)
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] results compare is: #{compare}"

        compare = single_run_bad.include?(sim)
        expect(compare).to be false
        
        objectives = {  
            objective_function_1: 20983305.555555556,
            objective_function_target_1: 0,
            objective_function_group_1: 1,
            objective_function_2: 24483569.444444444,
            objective_function_target_2: 0,
            objective_function_group_2: 2,
            objective_function_3: 1651205.5555555555,
            objective_function_target_3: 0,
            objective_function_group_3: 3,
            objective_function_4: 1814133.3333333333,
            objective_function_target_4: 0,
            objective_function_group_4: 4
        }
        
        #test the objectives.json 
        objectives_json = RestClient.get "http://#{@host}/data_points/#{data_point_id}/download_result_file?filename=objectives.json"
        objectives_json = JSON.parse(objectives_json, symbolize_names: true)
        expect(objectives_json).not_to be_nil
        
        #format the json for comparison
        obj_json = {}
        objectives_json.each do |key, value| 
          if key.to_s.include?("target") || key.to_s.include?("group")
            obj_json[key] = value.to_i
          else
            if Math.log10(value) > 6
              obj_json[key] = value.round(-6)
            else
              obj_json[key] = value.round(-5)
            end            
          end
        end
        #round test objectives {} for the comparison since repeatability is an issue
        cmp = []
        tmp = {}
        objectives.each do |key, value| 
          if key.to_s.include?("target") || key.to_s.include?("group")
            tmp[key] = value.to_i
          else
            if Math.log10(value) > 6
              tmp[key] = value.round(-6)
            else
              tmp[key] = value.round(-5)
            end            
          end
        end
        cmp << tmp
        compare = cmp.include?(obj_json)
        expect(compare).to be true
        puts "data_point[:#{data_point[:_id]}] objective.json compare is: #{compare}"
        
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
    
  end # urbanopt_single_run
end
