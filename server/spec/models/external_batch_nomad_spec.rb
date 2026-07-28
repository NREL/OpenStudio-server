# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'tmpdir'
require 'rbconfig'
require 'socket'

# Nomad control-plane helpers (submit_nomad.rb, sync_results.rb) exercised
# against a stub of the Nomad HTTP API — submit_nomad.rb drives
# POST /v1/jobs/parse and POST /v1/jobs, it never shells out to a `nomad` CLI.
# The full-pipeline spec walks the exact Nomad shape: package -> submit (push
# to NFS) -> array tasks run against the NFS copy -> sync results down -> ingest.
RSpec.describe 'ExternalBatch Nomad helpers', type: :model do
  include ExternalBatchHelpers

  NOMAD_DIR = File.expand_path('../external_batch/nomad', Rails.root)

  around do |example|
    Dir.mktmpdir do |tmp|
      @batch_root = File.join(tmp, 'batch')
      @nfs_root = File.join(tmp, 'fake_nfs') # simulates the shared NFS mount
      FileUtils.mkdir_p [@batch_root, @nfs_root]
      ENV['OS_SERVER_EXTERNAL_BATCH_ROOT'] = @batch_root
      begin
        example.run
      ensure
        ENV.delete('OS_SERVER_EXTERNAL_BATCH_ROOT')
      end
    end
  end

  before do
    begin
      Project.destroy_all
      Delayed::Job.destroy_all
    rescue Errno::EACCES
      puts 'Cannot unlink files, will try and continue'
    end
    @nomad_requests = []
    @nomad_api = TCPServer.new('127.0.0.1', 0)
    @nomad_addr = "http://127.0.0.1:#{@nomad_api.addr[1]}"
    @nomad_api_thread = Thread.new { serve_stub_nomad_api(@nomad_api, @nomad_requests) }
  end

  after do
    @nomad_api&.close
    @nomad_api_thread&.kill
  end

  # Minimal stub of the two Nomad API calls submit_nomad.rb makes:
  # POST /v1/jobs/parse (HCL -> job JSON) and POST /v1/jobs (submit).
  # Records each request so examples can assert on the rendered job.
  def serve_stub_nomad_api(server, requests)
    loop do
      client = begin
        server.accept
      rescue IOError, Errno::EBADF, Errno::EINVAL
        break
      end
      begin
        request_line = client.gets
        next unless request_line

        path = request_line.split(' ')[1]
        content_length = 0
        while (line = client.gets) && line != "\r\n"
          content_length = line.split(':', 2)[1].to_i if line.downcase.start_with?('content-length')
        end
        body = content_length.positive? ? client.read(content_length) : ''
        requests << { path: path, body: JSON.parse(body) }
        response = path == '/v1/jobs/parse' ? { 'ID' => 'stub-parsed-job' } : { 'EvalID' => 'stub-eval-123' }
        payload = JSON.generate(response)
        client.write "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}"
      ensure
        client.close
      end
    end
  end

  # submit_nomad.rb lays the shared location out as <package-location>/analysis_<id>/{package,results}
  def nfs_batch_dir(analysis)
    File.join(@nfs_root, "analysis_#{analysis.id}")
  end

  def submit!(analysis)
    system(RbConfig.ruby, File.join(NOMAD_DIR, 'submit_nomad.rb'),
           ExternalBatch.batch_dir(analysis.id),
           '--nomad-addr', @nomad_addr,
           '--job-template', File.join(NOMAD_DIR, 'templates', 'job_array.hcl'),
           '--package-location', @nfs_root)
  end

  describe 'submit_nomad.rb' do
    it 'pushes the package to the shared location and submits an array job sized to the chunk count' do
      analysis, dps = create_fixture_analysis(num_dps: 3)
      ExternalBatch::Packager.new(analysis, dps, dps_per_chunk: 2).package!

      expect(submit!(analysis)).to be(true), 'submit_nomad.rb exited non-zero'

      # package mirrored into the fake NFS root
      expect(File).to exist(File.join(nfs_batch_dir(analysis), 'package', 'manifest.json'))
      expect(Dir).to exist(File.join(nfs_batch_dir(analysis), 'package', "analysis_#{analysis.id}"))

      # HCL parsed then submitted, with the template rendered for 2 chunks
      expect(@nomad_requests.map { |r| r[:path] }).to eq ['/v1/jobs/parse', '/v1/jobs']
      hcl = @nomad_requests[0][:body]['JobHCL']
      expect(hcl).to include('count = 2') # 3 dps at 2/chunk = 2 array tasks
      expect(hcl).to include("osaf-nomad-analysis-#{analysis.id}")
      expect(hcl).to include(File.join(@nfs_root, "analysis_#{analysis.id}", 'package'))
      expect(hcl).to include(File.join(@nfs_root, "analysis_#{analysis.id}", 'results'))
      expect(@nomad_requests[1][:body]['Job']).to eq('ID' => 'stub-parsed-job')
    end

    it 'renders a single-task group for a single chunk' do
      analysis, dps = create_fixture_analysis(num_dps: 2)
      ExternalBatch::Packager.new(analysis, dps, dps_per_chunk: 50).package! # 1 chunk

      expect(submit!(analysis)).to be true

      hcl = @nomad_requests[0][:body]['JobHCL']
      expect(hcl).to include('count = 1')
    end
  end

  describe 'full Nomad-shaped pipeline' do
    it 'package -> submit -> array tasks against NFS copy -> sync_results -> ingest' do
      analysis, dps = create_fixture_analysis(num_dps: 2)
      ExternalBatch::Packager.new(analysis, dps, dps_per_chunk: 1).package!
      dps.each(&:set_queued_state)
      batch_dir = ExternalBatch.batch_dir(analysis.id)

      # 1. control plane: push package + submit the array job
      expect(submit!(analysis)).to be true

      # 2. the "array tasks": the NFS copy has the same shape as a local batch
      #    dir, so drive it with the local executor + stub OpenStudio CLI
      #    (this is what task_wrapper.sh does inside each Nomad task)
      stub_cli = write_stub_openstudio(@nfs_root)
      ok = system(RbConfig.ruby, File.expand_path('../external_batch/local_executor.rb', Rails.root),
                  nfs_batch_dir(analysis),
                  '--openstudio', "\"#{RbConfig.ruby}\" \"#{stub_cli}\"",
                  '--parallel', '2')
      expect(ok).to be(true), 'array-task simulation failed'

      # 3. transport: mirror the results down to the server's batch dir
      ok = system(RbConfig.ruby, File.join(NOMAD_DIR, 'sync_results.rb'), batch_dir,
                  '--results-uri', File.join(nfs_batch_dir(analysis), 'results'),
                  '--interval', '0')
      expect(ok).to be(true), 'sync_results.rb exited non-zero'

      # 4. ingest: the server-side loop sees the results as local files
      ingester = ExternalBatch::Ingester.new(analysis)
      expect(ingester.executor_finished?(2)).to be true
      expect(ingester.ingest_new_results).to eq 2

      dps.each do |dp|
        dp.reload
        expect(dp.status).to eq 'completed'
        expect(dp.status_message).to eq 'completed normal'
        expect(dp.results['stub_measure']['ran']).to eq true
      end
    end
  end
end
