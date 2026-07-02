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
require 'open3'
require 'socket'
require 'timeout'

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

def free_port
  server = TCPServer.new('127.0.0.1', 0)
  port = server.addr[1]
  server.close
  port
end

def start_stub_server(port, soft_stop_available: true, stop_available: false, failing_path: nil, failure_status: 500, failure_body: 'internal server error')
  zip_path = File.expand_path('../files/example_csv.zip', __dir__)
  zip_body = File.binread(zip_path)
  analysis_id = 'analysis-1'
  project_id = 'project-1'
  requests = []

  server = TCPServer.new('127.0.0.1', port)
  thread = Thread.new do
    loop do
      client = server.accept
      request_line = client.gets
      next unless request_line

      method, path, _http_version = request_line.split(' ')
      requests << [method, path]
      headers = {}
      while (line = client.gets)
        break if line == "\r\n"
        key, value = line.split(':', 2)
        headers[key.downcase] = value.strip if key && value
      end

      if headers['expect']&.downcase == '100-continue'
        client.write("HTTP/1.1 100 Continue\r\n\r\n")
      end

      if headers['transfer-encoding']&.downcase == 'chunked'
        loop do
          size_line = client.gets
          break unless size_line
          size = size_line.to_i(16)
          break if size.zero?
          client.read(size)
          client.read(2)
        end
        while (line = client.gets)
          break if line == "\r\n"
        end
      elsif headers['content-length'] && headers['content-length'].to_i.positive?
        client.read(headers['content-length'].to_i)
      end

      status = 200
      content_type = 'text/plain'
      body = 'ok'

      case path
      when failing_path
        status = failure_status
        body = failure_body
      when '/status.json'
        content_type = 'application/json'
        body = { status: { awake: true } }.to_json
      when '/projects.json'
        content_type = 'application/json'
        if method == 'POST'
          status = 201
          body = { _id: project_id }.to_json
        else
          body = [{ _id: project_id }].to_json
        end
      when %r{^/projects/.+/analyses\.json$}
        content_type = 'application/json'
        status = 201
        body = { _id: analysis_id }.to_json
      when %r{^/analyses/.+/upload\.json$}
        content_type = 'application/json'
        status = 201
        body = { uploaded: true }.to_json
      when %r{^/analyses/.+/soft_stop$}
        if soft_stop_available
          content_type = 'text/html'
          body = 'soft-stopped'
        else
          status = 404
          body = 'not found'
        end
      when %r{^/analyses/.+/stop$}
        if stop_available
          content_type = 'text/html'
          body = 'stopped'
        else
          status = 404
          body = 'not found'
        end
      when %r{^/analyses/.+/download_analysis_zip$}
        content_type = 'application/zip'
        body = zip_body
      when %r{^/analyses/.+\.json$}
        content_type = 'application/json'
        body = { analysis: { _id: analysis_id, run_flag: false, data_points: [] } }.to_json
      else
        status = 404
        body = 'not found'
      end

      response = +"HTTP/1.1 #{status} OK\r\n"
      response << "Content-Type: #{content_type}\r\n"
      response << "Content-Length: #{body.bytesize}\r\n"
      response << "Connection: close\r\n\r\n"
      response << body
      client.write(response)
      client.close
    rescue StandardError
      client.close rescue nil
    end
  end
  Timeout.timeout(10) do
    loop do
      begin
        RestClient.get("http://127.0.0.1:#{port}/status.json")
        break
      rescue StandardError
        sleep 0.1
      end
    end
  end

  [server, thread, analysis_id, requests]
end

# the actual tests
RSpec.describe 'CreateAnalysis command', type: :feature do
  it 'submits analysis to server and soft-stops after initialization' do
    port = free_port
    server, thread, _analysis_id, requests = start_stub_server(port)
    host = "http://127.0.0.1:#{port}"
    command = "#{ruby_cmd} \"#{meta_cli}\" create_analysis --debug --verbose \"#{project}/example_csv.json\" #{host} -z example_csv.zip -a batch_datapoints"
    puts command
    stdout = stderr = status = nil
    Bundler.with_unbundled_env do
      stdout, stderr, status = Open3.capture3(command)
    end

    expect(status.success?).to be true
    expect(stderr).to be_empty
    expect(stdout).to include('Analysis ID:')
    expect(stdout).to include("Server: #{host}")
    expect(stdout).to include("Formulation path: #{project}/example_csv.json")
    expect(stdout).to include("Zip path: #{project}/example_csv.zip")
    expect(stdout).to include('Analysis type: batch_datapoints')

    analysis_id = stdout.match(/Analysis ID:\s+([0-9a-zA-Z-]{3,})/)[1]
    analysis = JSON.parse(RestClient.get("#{host}/analyses/#{analysis_id}.json"), symbolize_names: true)[:analysis]
    expect(analysis).not_to be_nil
    expect(analysis[:run_flag]).to be false

    zip_response = RestClient.get "#{host}/analyses/#{analysis_id}/download_analysis_zip"
    expect(zip_response.headers[:content_type]).to include('application/zip')
    expect(zip_response.body.bytesize).to be > 0
    expect(requests.map(&:last)).to include("/analyses/#{analysis_id}/soft_stop")
  ensure
    server.close if server
    thread&.kill
  end
end

RSpec.describe 'CreateAnalysis command fallback behavior', type: :feature do
  it 'falls back to stop when soft_stop is unavailable' do
    port = free_port
    server, thread, _analysis_id, requests = start_stub_server(port, soft_stop_available: false, stop_available: true)
    host = "http://127.0.0.1:#{port}"
    command = "#{ruby_cmd} \"#{meta_cli}\" create_analysis --debug --verbose \"#{project}/example_csv.json\" #{host} -z example_csv.zip -a batch_datapoints"
    puts command
    stdout = stderr = status = nil
    Bundler.with_unbundled_env do
      stdout, stderr, status = Open3.capture3(command)
    end

    expect(status.success?).to be true
    expect(stderr).to be_empty
    expect(stdout).to include('Stopped analysis initialization')
    expect(requests.map(&:last)).to include("/analyses/analysis-1/soft_stop")
    expect(requests.map(&:last)).to include("/analyses/analysis-1/stop")
  ensure
    server.close if server
    thread&.kill
  end
end

RSpec.describe 'CreateAnalysis command failure behavior', type: :feature do
  it 'returns nonzero and surfaces server response details when analysis creation fails' do
    port = free_port
    server, thread, _analysis_id, _requests = start_stub_server(
      port,
      failing_path: '/projects/project-1/analyses.json',
      failure_status: 500,
      failure_body: '{"error":"analysis invalid"}'
    )
    host = "http://127.0.0.1:#{port}"
    command = "#{ruby_cmd} \"#{meta_cli}\" create_analysis --debug --verbose \"#{project}/example_csv.json\" #{host} -z example_csv.zip -a batch_datapoints"
    puts command
    stdout = stderr = status = nil
    Bundler.with_unbundled_env do
      stdout, stderr, status = Open3.capture3(command)
    end

    expect(status.success?).to be false
    expect(stdout).to include('Server request failed: HTTP 500')
    expect(stdout).to include('analysis invalid')
    expect(stderr).to be_empty
  ensure
    server.close if server
    thread&.kill
  end
end

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
