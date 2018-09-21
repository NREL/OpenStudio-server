# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
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
if Gem.win_platform?
  ENV['PATH'] = "C:/Program Files/MongoDB/Server/3.0/bin;#{ENV['PATH']}" # @todo it would be good to un-hard-code this
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

class LocalRspecTest
end

# Set obvious paths for start-local & run-analysis invocation
mongod_exe = which('mongod')
ruby_cmd = 'ruby'
meta_cli = File.absolute_path(File.join(File.dirname(__FILE__), '../../bin/openstudio_meta'))
project = File.absolute_path(File.join(File.dirname(__FILE__), '../files/'))
server_rspec_test_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../unit-test/'))

# Attempt to locate oscli if it is not set via env var for the rspec test
if ENV['OPENSTUDIO_TEST_EXE']
  unless File.exist? ENV['OPENSTUDIO_TEST_EXE']
    raise "Can't find OPENSTUDIO_TEST_EXE at #{ENV['OPENSTUDIO_TEST_EXE']}"
  end
else
  oscli_path = which('openstudio')
  if oscli_path
    ENV['OPENSTUDIO_TEST_EXE'] = oscli_path
    else
      raise "Can't find openstudio cli on path - please specify via env var OPENSTUDIO_TEST_EXE"
  end
end

# remove leftover files from previous tests if they exist
to_rm = [File.join(project, 'temp_data'), File.join(project, 'localResults')]
to_rm.each { |dir| FileUtils.rm_rf(dir) if Dir.exist? dir }
FileUtils.mkdir_p File.join(project, 'logs')
FileUtils.mkdir_p File.join(project, 'data/db')
FileUtils.mkdir_p File.join(server_rspec_test_dir, 'logs')
FileUtils.mkdir_p File.join(server_rspec_test_dir, 'data/db')
num_workers = 2
::ENV.delete 'BUNDLE_BIN_PATH'
::ENV.delete 'BUNDLE_GEMFILE'
::ENV.delete 'RUBYOPT'

# the actual tests
RSpec.describe OpenStudioMeta do
  before :all do
    # start the server
    command = "#{ruby_cmd} \"#{meta_cli}\" start_local --mongo-dir=\"#{File.dirname(mongod_exe)}\" --openstudio-exe-path=#{ENV['OPENSTUDIO_TEST_EXE']} --worker-number=#{num_workers} \"#{project}\""
    puts command
    start_local = system(command)
    expect(start_local).to be true
  end

  it 'run simple analysis' do
    # run an analysis
    command = "#{ruby_cmd} \"#{meta_cli}\" run_analysis \"#{project}/example_csv.json\" http://localhost:8080/ -a batch_datapoints"
    puts command
    run_analysis = system(command)
    expect(run_analysis).to be true

    a = RestClient.get 'http://localhost:8080/analyses.json'
    a = JSON.parse(a, symbolize_names: true)
    a = a.sort { |x, y| x[:created_at] <=> y[:created_at] }.reverse
    expect(a).not_to be_empty

    analysis = a[0]
    analysis_id = analysis[:_id]
    # used in after_each
    @analysis_id = analysis

    status = 'queued'
    timeout_seconds = 240
    begin
      ::Timeout.timeout(timeout_seconds) do
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
          # confirm that queueing is working
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
          sleep 5
        end
      end
    rescue ::Timeout::Error
      puts "Analysis status is `#{status}` after #{timeout_seconds} seconds; assuming error."
    end

    expect(status).to eq('completed')

  end

  it 'run a complicated design alternative analysis set' do
    # run an analysis
    command = "#{ruby_cmd} \"#{meta_cli}\" run_analysis \"#{project}/da_measures.json\" http://localhost:8080/ -a batch_datapoints"
    puts command
    run_analysis = system(command)
    expect(run_analysis).to be true

    a = RestClient.get 'http://localhost:8080/analyses.json'
    a = JSON.parse(a, symbolize_names: true)
    a = a.sort { |x, y| x[:created_at] <=> y[:created_at] }.reverse
    expect(a).not_to be_empty

    analysis = a[0]
    analysis_id = analysis[:_id]
    # used in after_each
    @analysis_id = analysis_id

    status = 'queued'
    timeout_seconds = 240
    begin
      ::Timeout.timeout(timeout_seconds) do
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
          sleep 5
        end
      end
    rescue ::Timeout::Error
      puts "Analysis status is `#{status}` after #{timeout_seconds} seconds; assuming error."
    end

    expect(status).to eq('completed')

  end

  after :each do
    # confirm that datapoints ran successfully
    a = RestClient.get 'http://localhost:8080/data_points.json'
    a = JSON.parse(a, symbolize_names: true)
    data_points = []
    a.each do |data_point|
      if data_point[:analysis_id] == @analysis_id
        data_points << data_point
      end
    end
    data_points.each do |data_point|
      a = RestClient.get "http://localhost:8080/data_points/#{data_point[:_id]}.json"
      a = JSON.parse(a, symbolize_names: true)
      expect(a[:data_point][:status_message]).to eq('completed normal')
    end
  end

  after :all do
    # stop the server
    command = "#{ruby_cmd} \"#{meta_cli}\" stop_local \"#{project}\""
    puts command
    stop_local = system(command)
    expect(stop_local).to be true
  end
end

