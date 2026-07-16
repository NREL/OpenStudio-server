# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Specs for the persistent worker->web HTTP client. These observe the client
# at the TCP level with a tiny in-process HTTP server, so they need no Rails
# boot, database, or docker stack.

require 'socket'
require 'json'
require 'tempfile'
require_relative '../../config/initializers/http_client'

# Minimal single-threaded HTTP/1.1 server that records every request and how
# many TCP connections were accepted. Connection counting is the point: the
# client exists to collapse many worker->web calls onto one connection.
class TinyHttpServer
  attr_reader :requests
  attr_accessor :response_status, :response_body, :close_connections

  def initialize
    @server = TCPServer.new('127.0.0.1', 0)
    @accepted = 0
    @requests = []
    @response_status = 200
    @response_body = '{"ok":true}'
    @close_connections = false
    @thread = Thread.new { accept_loop }
  end

  def base_url
    "http://127.0.0.1:#{@server.addr[1]}"
  end

  def accepted_connections
    @accepted
  end

  def stop
    @server.close
    @thread.kill
    @thread.join
  end

  private

  def accept_loop
    loop do
      sock = @server.accept
      @accepted += 1
      serve_connection(sock)
    end
  rescue IOError, Errno::EBADF
    nil # server socket closed by #stop
  end

  def serve_connection(sock)
    loop do
      request_line = sock.gets("\r\n")
      break if request_line.nil?

      headers = {}
      while (line = sock.gets("\r\n")) && line != "\r\n"
        key, value = line.chomp.split(': ', 2)
        headers[key.downcase] = value
      end
      body = headers['content-length'] ? sock.read(headers['content-length'].to_i) : ''
      method, path, = request_line.split(' ')
      @requests << { method: method, path: path, headers: headers, body: body }

      connection = @close_connections ? 'close' : 'keep-alive'
      sock.write "HTTP/1.1 #{@response_status} STATUS\r\n" \
                 "Content-Length: #{@response_body.bytesize}\r\n" \
                 "Connection: #{connection}\r\n\r\n#{@response_body}"
      break if @close_connections
    end
  ensure
    sock.close unless sock.closed?
  end
end

RSpec.describe OsHttp::Client do
  before :each do
    @server = TinyHttpServer.new
    @client = OsHttp::Client.new(base_url: @server.base_url)
  end

  after :each do
    @client.shutdown
    @server.stop
  end

  it 'reuses a single TCP connection across sequential requests' do
    # Validates: the conntrack fix itself. rest-client opened one connection
    # per call; all calls within a job must now share one socket.
    @client.delete("/data_points/123/result_files")
    @client.get("#{@server.base_url}/data_points/123.json")
    @client.get("#{@server.base_url}/analyses/456.json")

    expect(@server.requests.map { |r| [r[:method], r[:path]] }).to eq(
      [%w[DELETE /data_points/123/result_files],
       %w[GET /data_points/123.json],
       %w[GET /analyses/456.json]]
    )
    expect(@server.accepted_connections).to eq(1),
                                            "expected all #{@server.requests.length} requests on one TCP connection, " \
                                            "got #{@server.accepted_connections}"
  end

  it 'reconnects transparently when the server closes the connection' do
    # Validates: Puma closes keep-alive connections after its persistent
    # timeout; the client must open a new connection, not fail the job.
    @server.close_connections = true

    first = @client.get('/data_points/1.json')
    second = @client.get('/data_points/2.json')

    expect(first.code).to eq(200)
    expect(second.code).to eq(200)
    expect(@server.accepted_connections).to eq(2)
  end

  it 'returns a rest-client-compatible response' do
    # Validates: call sites rely on Integer #code, JSON.parse(response) via
    # #to_str, and log interpolation via #to_s.
    @server.response_body = '{"status":"completed"}'

    response = @client.get('/data_points/1.json')

    expect(response.code).to eq(200)
    expect(JSON.parse(response)['status']).to eq('completed')
    expect("#{response}").to eq('{"status":"completed"}')
  end

  it 'raises OsHttp::Error rescuable as StandardError on non-2xx responses' do
    # Validates: the worker retry loops rescue StandardError; rest-client
    # raised on non-2xx, so the replacement must too.
    @server.response_status = 422
    @server.response_body = 'unprocessable'

    expect { @client.get('/data_points/1.json') }.to raise_error(StandardError) do |e|
      expect(e).to be_a(OsHttp::Error)
      expect(e.code).to eq(422)
      expect(e.body).to eq('unprocessable')
      expect(e.message).to eq('HTTP 422 on GET /data_points/1.json')
    end
  end

  it 'posts rails-style nested multipart forms with mime-typed file parts' do
    # Regression: Net::HTTP#set_form defaults file parts to
    # application/octet-stream and silently ignores String-keyed part options.
    # DataPointsController#download_result_file serves files inline only for
    # text/html, application/json and text/plain, so the part Content-Type
    # must match what rest-client's mime guess produced.
    html_report = Tempfile.new(['report', '.html'])
    html_report.write('<html>eplustbl</html>')
    html_report.close
    attachment = File.new(html_report.path, 'rb')

    @client.post_form('/data_points/1/upload_file',
                      file: { display_name: nil,
                              type: 'Report',
                              attachment: attachment })

    request = @server.requests.last
    expect(request[:method]).to eq('POST')
    expect(request[:headers]['content-type']).to start_with('multipart/form-data; boundary=')

    body = request[:body]
    expect(body).to include('name="file[display_name]"') # nil coerced, not TypeError
    expect(body).to match(/name="file\[type\]"\r\n\r\nReport\r\n/)
    expect(body).to include("filename=\"#{File.basename(html_report.path)}\"") # basename, not full path
    expect(body).to include('Content-Type: text/html')
    expect(body).to include('<html>eplustbl</html>')
  ensure
    attachment&.close
    html_report&.unlink
  end

  it 'falls back to application/octet-stream for unknown file extensions' do
    # Validates: parity with rest-client for .osm/.osw/.mat uploads, which
    # mime-types does not know and which must stay disposition: attachment.
    osm = Tempfile.new(['model', '.osm'])
    osm.write('OS:Version,;')
    osm.close
    attachment = File.new(osm.path, 'rb')

    @client.post_form('/data_points/1/upload_file',
                      file: { display_name: 'model', type: 'OpenStudio Model',
                              attachment: attachment })

    expect(@server.requests.last[:body]).to include('Content-Type: application/octet-stream')
  ensure
    attachment&.close
    osm&.unlink
  end
end

RSpec.describe OsHttp do
  after :each do
    OsHttp.instance_variable_set(:@client, nil)
    OsHttp.instance_variable_set(:@client_base_url, nil)
  end

  it 'rebuilds the singleton client when os_server_host_url changes' do
    # Validates: the run_simulation feature specs repoint
    # APP_CONFIG['os_server_host_url'] at a per-process Capybara server after
    # boot; the memoized client must follow, as rest-client did by reading
    # APP_CONFIG on every call.
    stub_const('APP_CONFIG', { 'os_server_host_url' => 'http://127.0.0.1:9001' })
    first = OsHttp.client
    expect(OsHttp.client).to be(first) # stable while the URL is unchanged

    stub_const('APP_CONFIG', { 'os_server_host_url' => 'http://127.0.0.1:9002' })
    expect(OsHttp.client).not_to be(first)
  end

  it 'raises when os_server_host_url is not configured' do
    # Validates: fail loudly at first use, not with a nil URI error mid-job.
    hide_const('APP_CONFIG')
    expect { OsHttp.client }.to raise_error(/os_server_host_url/)
  end
end
