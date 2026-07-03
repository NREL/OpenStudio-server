# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'tmpdir'
require 'rbconfig'
require 'json'

describe 'ExternalBatch::Nomad sync_results.rb' do
  NOMAD_DIR = File.expand_path(File.dirname(__FILE__))

  around do |example|
    Dir.mktmpdir do |tmp|
      @batch_root = File.join(tmp, 'batch')
      @fake_nomad_root = File.join(tmp, 'fake_nomad')  # Simulates the shared storage (NFS or S3 root)
      FileUtils.mkdir_p [@batch_root, @fake_nomad_root]
      ENV['OS_SERVER_EXTERNAL_BATCH_ROOT'] = @batch_root
      ENV['FAKE_NOMAD_ROOT'] = @fake_nomad_root
      begin
        example.run
      ensure
        ENV.delete('OS_SERVER_EXTERNAL_BATCH_ROOT')
        ENV.delete('FAKE_NOMAD_ROOT')
      end
    end
  end

  def create_manifest_and_results(batch_dir, num_chunks: 2)
    # Create a minimal manifest.json
    manifest = {
      'analysis_id' => 123,
      'chunks' => (0...num_chunks).map do |i|
        {
          'index' => i,
          'data_point_ids' => [i*2 + 1, i*2 + 2] # Just dummy
        }
      end
    }
    package_dir = File.join(batch_dir, 'package')
    FileUtils.mkdir_p(package_dir)
    File.write(File.join(package_dir, 'manifest.json'), JSON.generate(manifest))

    # Create the results directory in the fake_nomad_root (simulating where Nomad writes results)
    results_dir_in_nomad = File.join(@fake_nomad_root, 'analysis_runs', 'analysis_123', 'results')
    FileUtils.mkdir_p(results_dir_in_nomad)
    # Create dummy done files for some chunks
    (0...num_chunks).each do |i|
      # Initially, no done files
    end
    [manifest, results_dir_in_nomad]
  end

  describe 'sync_results.rb' do
    it 'syncs results from the shared location and waits for all chunks to be done' do
      batch_dir = File.join(@batch_root, 'batch_1')
      FileUtils.mkdir_p(batch_dir)
      manifest, results_dir_in_nomad = create_manifest_and_results(batch_dir, num_chunks: 2)

      # Run sync_results in the background so we can simulate chunks completing
      pid = Process.spawn(RbConfig.ruby, File.join(NOMAD_DIR, 'sync_results.rb'),
                          batch_dir,
                          '--results-uri', results_dir_in_nomad,
                          '--interval', '0') # Check as fast as possible for testing
      # Give it a moment to start
      sleep 0.2

      # Simulate chunk 0 completing
      done_file_0 = File.join(results_dir_in_nomad, 'chunk_0.done')
      File.write(done_file_0, 'done')
      sleep 0.2

      # Simulate chunk 1 completing
      done_file_1 = File.join(results_dir_in_nomad, 'chunk_1.done')
      File.write(done_file_1, 'done')
      sleep 0.2

      # Now the sync_results should exit because all chunks are done
      Process.wait(pid)
      expect($?.success?).to be true

      # Check that the done files were synced to the batch dir results directory
      batch_results_dir = File.join(batch_dir, 'results')
      expect(File).to exist(File.join(batch_results_dir, 'chunk_0.done'))
      expect(File).to exist(File.join(batch_results_dir, 'chunk_1.done'))
    end

    it 'exits after one sync when --once is given' do
      batch_dir = File.join(@batch_root, 'batch_2')
      FileUtils.mkdir_p(batch_dir)
      manifest, results_dir_in_nomad = create_manifest_and_results(batch_dir, num_chunks: 2)

      ok = system(RbConfig.ruby, File.join(NOMAD_DIR, 'sync_results.rb'),
                  batch_dir,
                  '--results-uri', results_dir_in_nomad,
                  '--once')
      expect(ok).to be true

      # Even though no done files exist, it should have synced once (though there's nothing to sync)
      # The key is that it didn't wait for chunks to complete.
    end
  end
end