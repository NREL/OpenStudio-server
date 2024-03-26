# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
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
  ENV['PATH'] = "C:/Program Files/MongoDB/Server/6.0/bin;#{ENV['PATH']}" # @todo it would be good to un-hard-code this
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
bundle_cmd = 'bundle exec ruby'
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

# Uncomment below to remove leftover files from previous tests if they exist.
# Note that this can make debugging more difficult as logs in temp_data disappear after tests run.
# to_rm = [File.join(project, 'temp_data'), File.join(project, 'localResults')]
# to_rm.each { |dir| FileUtils.rm_rf(dir) if Dir.exist? dir }
#
FileUtils.mkdir_p File.join(project, 'logs')
FileUtils.mkdir_p File.join(project, 'data/db')
FileUtils.mkdir_p File.join(server_rspec_test_dir, 'logs')
FileUtils.mkdir_p File.join(server_rspec_test_dir, 'data/db')
num_workers = 2
::ENV.delete 'BUNDLE_BIN_PATH'
::ENV.delete 'BUNDLE_GEMFILE'
::ENV.delete 'RUBYOPT'

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../server/Gemfile', __dir__)

# the actual tests
RSpec.describe OpenStudioMeta do
  before :all do
    # start the server
    command = "#{ruby_cmd} \"#{meta_cli}\" start_local --debug --verbose --mongo-dir=\"#{File.dirname(mongod_exe)}\" --openstudio-exe-path=#{ENV['OPENSTUDIO_TEST_EXE']} --worker-number=#{num_workers} \"#{project}\""
    puts command
    start_local = system(command)
    expect(start_local).to be true
  end

  it 'run simple analysis' do
    # run an analysis
    command = "#{bundle_cmd} \"#{meta_cli}\" run_analysis --debug --verbose \"#{project}/example_csv.json\" http://localhost:8080/ -a batch_datapoints"
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
    command = "#{bundle_cmd} \"#{meta_cli}\" run_analysis --debug --verbose \"#{project}/da_measures.json\" http://localhost:8080/ -a batch_datapoints"
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
      # l = RestClient.get "http://localhost:8080/data_points/#{data_point[:_id]}/download_result_file?filename=#{data_point[:_id]}.log"
      # expect(l).to eq('hack to view oscli output')
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

