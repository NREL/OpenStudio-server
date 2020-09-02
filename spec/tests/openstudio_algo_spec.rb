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
# Before running this test you have to build the server:
#
#   ruby bin/openstudio_meta install_gems
#
# You can edit \server\.bundle\config to remove 'development:test' after running
# the install command
#################################################################################

require 'rest-client'
require 'json'

class OpenStudioAlgo
end

# Set obvious paths for start-local & run-analysis invocation
ruby_cmd = 'ruby'
meta_cli = File.absolute_path('/opt/openstudio/bin/openstudio_meta')
project = File.absolute_path(File.join(File.dirname(__FILE__), '../files/'))
server_rspec_test_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../unit-test/'))
host = '127.0.0.1'

# the actual tests
describe OpenStudioAlgo do
  #before :all do
  #start server
  
  #gem install
    #command = "#{ruby_cmd} #{meta_cli} install_gems"
    #puts command
    #run_analysis = system(command)
    #expect(run_analysis).to be true
  #end
   
  it 'run nsga_nrel analysis' do
    #setup expected results
    nsga_nrel = [
    {:electricity_consumption_cvrmse => 21.891783184003916,
     :electricity_consumption_nmbe => 21.219852340971187,
     :natural_gas_consumption_cvrmse => 74.0377155095538,
     :natural_gas_consumption_nmbe => 48.74870573833565},
    {:electricity_consumption_cvrmse => 81.17990250370966,
     :electricity_consumption_nmbe => -84.09361390271116,
     :natural_gas_consumption_cvrmse => 44.49957965984623,
     :natural_gas_consumption_nmbe => 22.609405641934835},
    {:electricity_consumption_cvrmse => 27.597238464625097,
     :electricity_consumption_nmbe => 27.065721540157966,
     :natural_gas_consumption_cvrmse => 76.85534154885444,
     :natural_gas_consumption_nmbe => 51.01379372340268},
    {:electricity_consumption_cvrmse => 23.78734278681941,
     :electricity_consumption_nmbe => 23.28284663614307,
     :natural_gas_consumption_cvrmse => 81.49102927940706,
     :natural_gas_consumption_nmbe => 55.11899202056254}
    ]
    #setup bad results
    nsga_nrel_bad = [
     {:electricity_consumption_cvrmse => 0,
      :electricity_consumption_nmbe => 0,
      :natural_gas_consumption_cvrmse => 0,
      :natural_gas_consumption_nmbe => 0}
    ]

    # run an analysis
    command = "#{ruby_cmd} #{meta_cli} run_analysis --debug --verbose '#{project}/SEB_calibration_NSGA_2013.json' 'http://#{host}' -a nsga_nrel"
    puts "run command: #{command}"
    run_analysis = system(command)
    expect(run_analysis).to be true

    a = RestClient.get "http://#{host}/analyses.json"
    a = JSON.parse(a, symbolize_names: true)
    a = a.sort { |x, y| x[:created_at] <=> y[:created_at] }.reverse
    expect(a).not_to be_empty
    analysis = a[0]
    analysis_id = analysis[:_id]

    status = 'queued'
    timeout_seconds = 480
    begin
      ::Timeout.timeout(timeout_seconds) do
        while status != 'completed'
          # get the analysis pages
          get_count = 0
          get_count_max = 50
          begin
            a = RestClient.get "http://#{host}/analyses/#{analysis_id}/status.json"
            a = JSON.parse(a, symbolize_names: true)
            analysis_type = a[:analysis][:analysis_type]
            expect(analysis_type).to eq('nsga_nrel')
          
            status = a[:analysis][:status]
            expect(status).not_to be_nil
            puts "Accessed pages for analysis: #{analysis_id}, analysis_type: #{analysis_type}, status: #{status}"

            # get all data points in this analysis
            a = RestClient.get "http://#{host}/data_points.json"
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
            
              a = RestClient.get "http://#{host}/data_points/#{data_point_id}.json"
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
      dps = RestClient.get "http://#{host}/data_points.json"
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
        dp = RestClient.get "http://#{host}/data_points/#{data_point[:_id]}.json"
        dp = JSON.parse(dp, symbolize_names: true)
        expect(dp[:data_point][:status_message]).to eq('completed normal')
      
        results = dp[:data_point][:results][:calibration_reports_enhanced_20]
        expect(results).not_to be_nil
        sim = results.slice(:electricity_consumption_cvrmse, :electricity_consumption_nmbe ,:natural_gas_consumption_cvrmse, :natural_gas_consumption_nmbe)
        expect(sim.size).to eq(4)
      
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
  end
  #after :all do
    # stop the server
  #end
end

