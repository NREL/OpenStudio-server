# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Per-process persistent HTTP client for worker -> web-server calls.
#
# Replaces rest-client for the DjJobs::RunSimulateDataPoint call sites. Each
# rest-client call opened a fresh TCP connection and left a TIME_WAIT socket
# behind, and every closed connection holds an nf_conntrack entry for ~120s.
# At high worker counts that churn can exhaust nf_conntrack_max on the nodes
# hosting the web tier. Routing the calls through one persistent connection
# per process cuts the connection churn by roughly an order of magnitude.
#
# Behavior parity with the previous rest-client usage:
#   * `.get` / `.delete` / `.post_form` return a Response exposing `.code`
#     (Integer) and `.body`, usable with JSON.parse (via `to_str`) and string
#     interpolation (via `to_s`).
#   * Non-2xx responses raise OsHttp::Error (a StandardError), matching
#     rest-client, so the existing `rescue StandardError` retry loops behave
#     the same.
#   * Multipart file parts carry the same filename (basename) and Content-Type
#     (mime guess by extension) that rest-client produced. The part
#     Content-Type is load-bearing: DataPointsController#download_result_file
#     stores it and serves files inline only for text/html, application/json,
#     and text/plain.
#
# Resque forks a child per job; the client is built lazily so each child opens
# its own connection on first use. Delayed Job workers are long-lived and
# reuse the connection across jobs.
#
# Usage:
#   OsHttp.client.get("#{APP_CONFIG['os_server_host_url']}/data_points/#{id}.json")
#   OsHttp.client.delete("/data_points/#{id}/result_files")
#   OsHttp.client.post_form(url, file: { display_name: name, type: type,
#                                        attachment: File.new(path, 'rb') })

require 'net/http/persistent'
require 'uri'

module OsHttp
  class Error < StandardError
    attr_reader :code, :body

    def initialize(code, body, msg)
      @code = code
      @body = body
      super(msg)
    end
  end

  # Duck-types the subset of RestClient::Response the worker code relies on.
  class Response
    attr_reader :code, :body

    def initialize(code, body)
      @code = code
      @body = body
    end

    def to_s
      body.to_s
    end

    # Keeps JSON.parse(response) working.
    def to_str
      body.to_s
    end
  end

  class Client
    # Content-Type for multipart file parts, matching what rest-client's
    # MIME::Types.type_for guess produced for the file types the worker
    # uploads. Unlisted extensions fall back to application/octet-stream,
    # which is also what rest-client did.
    PART_CONTENT_TYPES = {
      '.html' => 'text/html',
      '.json' => 'application/json',
      '.csv' => 'text/csv',
      '.xml' => 'text/xml',
      '.zip' => 'application/zip',
      '.txt' => 'text/plain',
      '.log' => 'text/plain',
      '.gz' => 'application/gzip'
    }.freeze
    DEFAULT_PART_CONTENT_TYPE = 'application/octet-stream'

    # idle_timeout must stay below Puma's persistent timeout (20s default) so
    # the client reopens idle connections instead of racing a server-side
    # close, which net/http cannot transparently retry for POSTs.
    def initialize(base_url:, idle_timeout: 15, read_timeout: 120, open_timeout: 15, pool_size: 1)
      @base = URI(base_url)
      @http = Net::HTTP::Persistent.new(name: 'os-server', pool_size: pool_size)
      @http.idle_timeout = idle_timeout
      @http.read_timeout = read_timeout
      @http.open_timeout = open_timeout
    end

    def get(path, headers = {})
      request(Net::HTTP::Get.new(uri_for(path).request_uri, headers))
    end

    def delete(path, headers = {})
      request(Net::HTTP::Delete.new(uri_for(path).request_uri, headers))
    end

    # Multipart form POST, shaped like the rest-client Hash payloads it
    # replaces: { file: { display_name: ..., attachment: File } } becomes
    # file[display_name]=... / file[attachment]=<upload>, matching the
    # Rails nested-params convention the controllers expect.
    def post_form(path, form_hash, headers = {})
      req = Net::HTTP::Post.new(uri_for(path).request_uri, headers)
      req.set_form(flatten_form(form_hash), 'multipart/form-data')
      request(req)
    end

    def shutdown
      @http.shutdown
    rescue StandardError
      # nothing useful to do at process exit
    end

    private

    def uri_for(path)
      path.to_s.start_with?('http') ? URI(path) : URI.join(@base.to_s, path)
    end

    def request(req)
      res = @http.request(@base, req)
      unless res.is_a?(Net::HTTPSuccess)
        raise Error.new(res.code.to_i, res.body, "HTTP #{res.code} on #{req.method} #{req.path}")
      end

      Response.new(res.code.to_i, res.body)
    end

    def flatten_form(hash)
      hash.flat_map do |k, v|
        if v.is_a?(Hash)
          v.map { |sub_k, sub_v| form_entry("#{k}[#{sub_k}]", sub_v) }
        else
          [form_entry(k.to_s, v)]
        end
      end
    end

    # Net::HTTP#set_form entries are [name, value] or [name, IO, opts]. The
    # opts keys must be Symbols - String keys are silently ignored and the
    # part falls back to application/octet-stream. Non-IO values must be
    # Strings; set_form raises TypeError on nil.
    def form_entry(key, value)
      if value.respond_to?(:read) && value.respond_to?(:path)
        [key, value, { filename: File.basename(value.path), content_type: part_content_type(value.path) }]
      else
        [key, value.to_s]
      end
    end

    def part_content_type(path)
      PART_CONTENT_TYPES.fetch(File.extname(path).downcase, DEFAULT_PART_CONTENT_TYPE)
    end
  end

  # Lazily-constructed singleton: this file must not depend on APP_CONFIG load
  # order, and forked workers should open their own connection on first use.
  def self.client
    @client ||= begin
      unless defined?(APP_CONFIG) && APP_CONFIG['os_server_host_url']
        raise "APP_CONFIG['os_server_host_url'] must be set before using OsHttp.client"
      end

      c = Client.new(base_url: APP_CONFIG['os_server_host_url'])
      at_exit { c.shutdown }
      c
    end
  end
end
