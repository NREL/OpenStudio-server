# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'tmpdir'
require 'rbconfig'

# AWS Batch control-plane helpers (submit_batch.rb, sync_results.rb) exercised
# against a stub `aws` CLI that emulates S3 as a local folder. The full-pipeline
# spec walks the exact AWS shape: package -> submit (push to "S3") -> array
# tasks run against the S3 copy -> sync results down -> ingest.
RSpec.describe 'ExternalBatch AWS helpers', type: :model do
  include ExternalBatchHelpers

  AWS_DIR = File.expand_path('../external_batch/aws', Rails.root)

  around do |example|
    Dir.mktmpdir do |tmp|
      @batch_root = File.join(tmp, 'batch')
      @fake_s3 = File.join(tmp, 'fake_s3')
      @stub_log = File.join(tmp, 'aws_calls.log')
      FileUtils.mkdir_p [@batch_root, @fake_s3]
      ENV['OS_SERVER_EXTERNAL_BATCH_ROOT'] = @batch_root
      ENV['FAKE_S3_ROOT'] = @fake_s3
      ENV['AWS_STUB_LOG'] = @stub_log
      begin
        example.run
      ensure
        ENV.delete('OS_SERVER_EXTERNAL_BATCH_ROOT')
        ENV.delete('FAKE_S3_ROOT')
        ENV.delete('AWS_STUB_LOG')
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
    @aws_cmd = "\"#{RbConfig.ruby}\" \"#{write_stub_aws(@fake_s3)}\""
  end

  def fake_s3_batch_dir(bucket, analysis)
    File.join(@fake_s3, bucket, 'runs', "analysis_#{analysis.id}")
  end

  describe 'submit_batch.rb' do
    it 'pushes the package to S3 and submits an array job sized to the chunk count' do
      analysis, dps = create_fixture_analysis(num_dps: 3)
      ExternalBatch::Packager.new(analysis, dps, dps_per_chunk: 2).package!

      ok = system(RbConfig.ruby, File.join(AWS_DIR, 'submit_batch.rb'),
                  ExternalBatch.batch_dir(analysis.id),
                  '--bucket', 'test-bucket',
                  '--job-queue', 'test-queue',
                  '--job-definition', 'test-jobdef',
                  '--aws-cmd', @aws_cmd)
      expect(ok).to be(true), 'submit_batch.rb exited non-zero'

      # package mirrored into the fake S3 bucket
      expect(File).to exist(File.join(fake_s3_batch_dir('test-bucket', analysis), 'package', 'manifest.json'))
      expect(Dir).to exist(File.join(fake_s3_batch_dir('test-bucket', analysis), 'package', "analysis_#{analysis.id}"))

      # submit-job called with the right shape
      calls = File.readlines(@stub_log).map { |l| JSON.parse(l) }
      submit = calls.detect { |c| c[0] == 'batch' && c[1] == 'submit-job' }
      expect(submit).not_to be_nil
      expect(submit).to include('--job-queue', 'test-queue', '--job-definition', 'test-jobdef')
      expect(submit.join(' ')).to include('size=2') # 3 dps at 2/chunk = 2 array tasks
      expect(submit.join(' ')).to include("BATCH_S3_URI,value=s3://test-bucket/runs/analysis_#{analysis.id}")
    end

    it 'submits a plain job with CHUNK_INDEX for a single chunk (Batch arrays need size >= 2)' do
      analysis, dps = create_fixture_analysis(num_dps: 2)
      ExternalBatch::Packager.new(analysis, dps, dps_per_chunk: 50).package! # 1 chunk

      ok = system(RbConfig.ruby, File.join(AWS_DIR, 'submit_batch.rb'),
                  ExternalBatch.batch_dir(analysis.id),
                  '--bucket', 'test-bucket', '--job-queue', 'q', '--job-definition', 'jd',
                  '--aws-cmd', @aws_cmd)
      expect(ok).to be true

      submit = File.readlines(@stub_log).map { |l| JSON.parse(l) }.detect { |c| c[1] == 'submit-job' }
      expect(submit.join(' ')).not_to include('--array-properties')
      expect(submit.join(' ')).to include('CHUNK_INDEX,value=0')
    end
  end

  describe 'full AWS-shaped pipeline' do
    it 'package -> submit -> array tasks against S3 copy -> sync_results -> ingest' do
      analysis, dps = create_fixture_analysis(num_dps: 2)
      ExternalBatch::Packager.new(analysis, dps, dps_per_chunk: 1).package!
      dps.each(&:set_queued_state)
      batch_dir = ExternalBatch.batch_dir(analysis.id)
      s3_uri = "s3://test-bucket/runs/analysis_#{analysis.id}"

      # 1. control plane: push package + "submit" the array job
      ok = system(RbConfig.ruby, File.join(AWS_DIR, 'submit_batch.rb'), batch_dir,
                  '--bucket', 'test-bucket', '--job-queue', 'q', '--job-definition', 'jd',
                  '--aws-cmd', @aws_cmd)
      expect(ok).to be true

      # 2. the "array tasks": the fake-S3 batch dir has the same shape as a local
      #    batch dir, so drive it with the local executor + stub OpenStudio CLI
      #    (this is what task_wrapper.sh does inside each container)
      stub_cli = write_stub_openstudio(@fake_s3)
      ok = system(RbConfig.ruby, File.expand_path('../external_batch/local_executor.rb', Rails.root),
                  fake_s3_batch_dir('test-bucket', analysis),
                  '--openstudio', "\"#{RbConfig.ruby}\" \"#{stub_cli}\"",
                  '--parallel', '2')
      expect(ok).to be(true), 'array-task simulation failed'

      # 3. transport: mirror the S3 results down to the server's batch dir
      ok = system(RbConfig.ruby, File.join(AWS_DIR, 'sync_results.rb'), batch_dir,
                  '--s3-uri', s3_uri, '--aws-cmd', @aws_cmd, '--interval', '0')
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
