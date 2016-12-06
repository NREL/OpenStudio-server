# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
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

# mongod must be in the path, if you are on Windows you can use the following
if /mingw/.match(RUBY_PLATFORM) || /win/.match(RUBY_PLATFORM)
  ENV['PATH'] = "C:/Program Files/MongoDB/Server/3.0/bin;#{ENV['PATH']}" #@todo it would be good to un-hard-code this
end

def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

# bogus class because I don't understand RSpec
class OpenStudioMeta
end

mongod_exe = which('mongod')
ruby_cmd = "\"#{RbConfig.ruby}\"" # full path if you care
ruby_cmd = 'ruby'
meta_cli = File.absolute_path(File.join(File.dirname(__FILE__), '../../bin/openstudio_meta'))
project = File.absolute_path(File.join(File.dirname(__FILE__), '../files/'))
FileUtils.mkdir_p File.join(project, 'logs')
FileUtils.mkdir_p File.join(project, 'data/db')
num_workers = 2
::ENV.delete 'BUNDLE_BIN_PATH'
::ENV.delete 'BUNDLE_GEMFILE'
::ENV.delete 'RUBYOPT'

# the actual tests
RSpec.describe OpenStudioMeta do
  before :all do
    # start the server
    command = "#{ruby_cmd} \"#{meta_cli}\" start_local --mongo-dir=\"#{File.dirname(mongod_exe)}\" --worker-number=#{num_workers} --debug --verbose \"#{project}\""
    puts command
    start_local = system(command)
    expect(start_local).to be true
  end

  it 'run simple analysis' do
    # run an analysis
    command = "#{ruby_cmd} \"#{meta_cli}\" run_analysis --debug --verbose \"#{project}/example_csv.json\" http://localhost:8080/ -a batch_datapoints"
    puts command
    run_analysis = system(command)
    expect(run_analysis).to be true

    a = RestClient.get 'http://localhost:8080/analyses.json'
    a = JSON.parse(a, symbolize_names: true)
    a = a.sort { |x, y| x[:created_at] <=> y[:created_at] }.reverse
    expect(a).not_to be_empty

    analysis = a[0]
    analysis_id = analysis[:_id]

    status = 'queued'
    begin
      ::Timeout.timeout(120) do
        while status != 'completed'
          # get the analysis pages
          a = RestClient.get "http://localhost:8080/analyses/#{analysis_id}.json"
          a = RestClient.get "http://localhost:8080/analyses/#{analysis_id}.html"
          a = RestClient.get "http://localhost:8080/analyses/#{analysis_id}/status.json"
          a = JSON.parse(a, symbolize_names: true)
          status = a[:analysis][:status]
          expect(status).not_to be_nil
          puts "Accessed pages for analysis #{analysis_id}, status = #{status}"

          # get all data points in this analysis
          a = RestClient.get 'http://localhost:8080/data_points.json'
          a = JSON.parse(a, symbolize_names: true)
          data_points = []
          a.each do |data_point|
            if data_point[:analysis_id] == analysis_id
              data_points << data_point
            end
          end

          data_points.each do |data_point|
            # get the datapoint pages
            data_point_id = data_point[:_id]
            a = RestClient.get "http://localhost:8080/data_points/#{data_point_id}.html"
            a = RestClient.get "http://localhost:8080/data_points/#{data_point_id}.json"
            a = JSON.parse(a, symbolize_names: true)
            status = a[:data_point][:status]
            expect(status).not_to be_nil
            puts "Accessed pages for data_point #{data_point_id}, status = #{status}"
          end
          puts ''
          sleep 1
        end
      end
    rescue ::Timeout::Error
      puts "Analysis status is `#{status}` after 90 seconds; assuming error."
    end

    expect(status).to eq('completed')
  end

  it 'run a complicated design alternative set' do
    # run an analysis
    command = "#{ruby_cmd} \"#{meta_cli}\" run_analysis --debug --verbose \"#{project}/da_measures.json\" http://localhost:8080/ -a batch_datapoints"
    puts command
    run_analysis = system(command)
    expect(run_analysis).to be true

    a = RestClient.get 'http://localhost:8080/analyses.json'
    a = JSON.parse(a, symbolize_names: true)
    a = a.sort { |x, y| x[:created_at] <=> y[:created_at] }.reverse
    expect(a).not_to be_empty

    analysis = a[0]
    analysis_id = analysis[:_id]

    status = 'queued'
    begin
      ::Timeout.timeout(120) do
        while status != 'completed'
          # get the analysis pages
          a = RestClient.get "http://localhost:8080/analyses/#{analysis_id}.json"
          a = RestClient.get "http://localhost:8080/analyses/#{analysis_id}.html"
          a = RestClient.get "http://localhost:8080/analyses/#{analysis_id}/status.json"
          a = JSON.parse(a, symbolize_names: true)
          status = a[:analysis][:status]
          expect(status).not_to be_nil
          puts "Accessed pages for analysis #{analysis_id}, status = #{status}"

          # get all data points in this analysis
          a = RestClient.get 'http://localhost:8080/data_points.json'
          a = JSON.parse(a, symbolize_names: true)
          data_points = []
          a.each do |data_point|
            if data_point[:analysis_id] == analysis_id
              data_points << data_point
            end
          end

          data_points.each do |data_point|
            # get the datapoint pages
            data_point_id = data_point[:_id]
            a = RestClient.get "http://localhost:8080/data_points/#{data_point_id}.html"
            a = RestClient.get "http://localhost:8080/data_points/#{data_point_id}.json"
            a = JSON.parse(a, symbolize_names: true)
            status = a[:data_point][:status]
            expect(status).not_to be_nil
            puts "Accessed pages for data_point #{data_point_id}, status = #{status}"
          end
          puts ''
          sleep 1
        end
      end
    rescue ::Timeout::Error
      puts "Analysis status is `#{status}` after 90 seconds; assuming error."
    end

    expect(status).to eq('completed')
  end

  after :all do
    # stop the server
    command = "#{ruby_cmd} \"#{meta_cli}\" stop_local \"#{project}\""
    puts command
    stop_local = system(command)
    expect(stop_local).to be true
  end
end
