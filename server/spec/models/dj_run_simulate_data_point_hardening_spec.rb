# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'tmpdir'
require 'zip'

# Regression specs for DjJobs::RunSimulateDataPoint#initialize_worker/#write_lock.
# After Redis lock migration, initialize_worker should always enter write_lock when
# receipt_file is missing (even if analysis_zip.lock exists). A corrupt analysis.zip
# must still fail deterministically without retrying extraction.
#
# See dj_run_simulation_data_point_spec.rb for the full Capybara/Resque integration
# coverage of this class (including the original 'creates a write lock that is
# threadsafe' example). These specs isolate the pure Ruby file/state control flow the
# same way that example does -- no depends_resque/js Capybara stack -- mirroring the
# non-feature style already used at the bottom of that file (the '#inline_log_lines'
# block) and the sibling regression style in spec/models/analysis_init_spec.rb.
RSpec.describe DjJobs::RunSimulateDataPoint, type: :model do
  around do |example|
    @tmp_sim_root = Dir.mktmpdir('dj-run-simulate-data-point-hardening')
    previous_sim_root_path = APP_CONFIG['sim_root_path']
    APP_CONFIG['sim_root_path'] = @tmp_sim_root
    example.run
  ensure
    APP_CONFIG['sim_root_path'] = previous_sim_root_path
    FileUtils.rm_rf(@tmp_sim_root) if @tmp_sim_root
  end

  before do
    Project.destroy_all
  end

  after do
    Project.destroy_all
  end

  # Bare, unsaved-then-saved Project/Analysis/DataPoint records -- the same lightweight
  # construction the existing 'creates a write lock that is threadsafe' example in
  # dj_run_simulation_data_point_spec.rb uses, rather than the heavier FactoryBot chain
  # (which attaches a real seed_zip and is not needed here).
  let(:project) { Project.new.tap(&:save!) }
  let(:analysis) { Analysis.new(project_id: project.id).tap(&:save!) }
  let(:data_point) { DataPoint.new(analysis_id: analysis.id).tap(&:save!) }

  def build_job(redis_lock_client: nil)
    job = described_class.new(data_point.id)
    allow(job).to receive(:redis_lock_client).and_return(redis_lock_client)
    job
  end

  describe '#initialize_worker lock behavior' do
    it 'returns early when receipt_file already exists' do
      job = build_job
      receipt_file = File.join(job.send(:analysis_dir), 'analysis_zip.receipt')
      FileUtils.mkdir_p(job.send(:analysis_dir))
      File.write(receipt_file, Time.now.to_s)

      expect(job).not_to receive(:write_lock)
      result = job.initialize_worker

      expect(result).to be true
    end

    it 'always goes through write_lock when receipt_file is missing, even if analysis_zip.lock already exists' do
      analysis.initialize_worker_timeout = 20
      analysis.save!

      job = build_job
      write_lock_file = File.join(job.send(:analysis_dir), 'analysis_zip.lock')
      receipt_file = File.join(job.send(:analysis_dir), 'analysis_zip.receipt')
      FileUtils.mkdir_p(job.send(:analysis_dir))
      File.write(write_lock_file, 'pre-existing lock marker')

      expect(job).not_to receive(:run_script_with_args)
      expect(job).not_to receive(:run_bundle_gems)
      expect(job).to receive(:write_lock).with(
        write_lock_file,
        receipt_file_path: receipt_file,
        wait_timeout: analysis.initialize_worker_timeout
      ).once do |_lock_path, _opts, &_blk|
        File.write(receipt_file, Time.now.to_s)
        true
      end

      result = job.initialize_worker

      expect(result).to be true
      expect(File.exist?(receipt_file)).to be true
    end
  end

  describe '#write_lock' do
    subject(:job) { described_class.allocate } # write_lock touches no @data_point/@sim_logger state, so a full DB-backed instance is unnecessary

    it 'removes the lock file (not just releasing the flock) when the protected block raises' do
      Dir.mktmpdir do |dir|
        lock_path = File.join(dir, 'analysis_zip.lock')
        job = described_class.allocate
        allow(job).to receive(:redis_lock_client).and_return(nil)

        expect { job.write_lock(lock_path) { raise 'boom' } }.to raise_error('boom')
        expect(File.exist?(lock_path)).to be false
      end
    end

    it 'leaves the lock file in place when the protected block succeeds (only the flock is released)' do
      Dir.mktmpdir do |dir|
        lock_path = File.join(dir, 'analysis_zip.lock')
        job = described_class.allocate
        allow(job).to receive(:redis_lock_client).and_return(nil)

        result = job.write_lock(lock_path) { 'downloaded ok' }

        expect(result).to eq 'downloaded ok'
        expect(File.exist?(lock_path)).to be true
      end
    end

    it 'uses a Redis lease when one is available' do
      Dir.mktmpdir do |dir|
        lock_path = File.join(dir, 'analysis_zip.lock')
        lock_key = "analysis_zip.lock:#{File.basename(File.dirname(lock_path))}"
        fake_redis = instance_double('Redis')
        renewal_thread = instance_double(Thread, kill: nil, join: nil)
        job = described_class.allocate

        allow(job).to receive(:redis_lock_client).and_return(fake_redis)
        allow(Thread).to receive(:new).and_return(renewal_thread)
        expect(fake_redis).to receive(:set).with(lock_key, kind_of(String), nx: true, px: 120_000).and_return(true)
        expect(fake_redis).to receive(:eval).with(kind_of(String), [lock_key], kind_of(Array)).and_return(1)

        result = job.write_lock(lock_path) { 'downloaded ok' }

        expect(result).to eq 'downloaded ok'
        expect(File.exist?(lock_path)).to be true
      end
    end

    it 'retries Redis lock acquisition until it succeeds' do
      Dir.mktmpdir do |dir|
        lock_path = File.join(dir, 'analysis_zip.lock')
        lock_key = "analysis_zip.lock:#{File.basename(File.dirname(lock_path))}"
        fake_redis = instance_double('Redis')
        renewal_thread = instance_double(Thread, kill: nil, join: nil)
        job = described_class.allocate

        allow(job).to receive(:redis_lock_client).and_return(fake_redis)
        allow(job).to receive(:sleep)
        allow(Thread).to receive(:new).and_return(renewal_thread)
        expect(fake_redis).to receive(:set).with(lock_key, kind_of(String), nx: true, px: 120_000).and_return(nil, nil, true)
        expect(fake_redis).to receive(:eval).with(kind_of(String), [lock_key], kind_of(Array)).and_return(1)

        result = job.write_lock(lock_path, wait_timeout: 5) { 'downloaded ok' }

        expect(result).to eq 'downloaded ok'
      end
    end

    it 'returns early when receipt appears while waiting on a Redis lock' do
      Dir.mktmpdir do |dir|
        lock_path = File.join(dir, 'analysis_zip.lock')
        lock_key = "analysis_zip.lock:#{File.basename(File.dirname(lock_path))}"
        receipt_path = File.join(dir, 'analysis_zip.receipt')
        fake_redis = instance_double('Redis')
        job = described_class.allocate

        allow(job).to receive(:redis_lock_client).and_return(fake_redis)
        allow(job).to receive(:sleep) { File.write(receipt_path, Time.now.to_s) }
        expect(fake_redis).to receive(:set).with(lock_key, kind_of(String), nx: true, px: 120_000).and_return(nil, nil)
        expect(fake_redis).not_to receive(:eval)

        yielded = false
        result = job.write_lock(lock_path, receipt_file_path: receipt_path, wait_timeout: 5) do
          yielded = true
        end

        expect(result).to be_nil
        expect(yielded).to be false
      end
    end

    it 'retries local flock acquisition until it succeeds' do
      lock_path = '/tmp/analysis_zip.lock'
      lock_file = instance_double(File, closed?: false)
      job = described_class.allocate

      allow(job).to receive(:redis_lock_client).and_return(nil)
      allow(job).to receive(:sleep)
      allow(File).to receive(:open).with(lock_path, 'a').and_return(lock_file)
      expect(lock_file).to receive(:flock).with(File::LOCK_EX | File::LOCK_NB).and_return(false, false, true)
      expect(lock_file).to receive(:<<).with(kind_of(Time))
      expect(lock_file).to receive(:flock).with(File::LOCK_UN).once
      expect(lock_file).to receive(:close).once

      result = job.write_lock(lock_path, wait_timeout: 5) { 'downloaded ok' }

      expect(result).to eq 'downloaded ok'
    end

    it 'enforces wait_timeout for local flock acquisition' do
      lock_path = '/tmp/analysis_zip.lock'
      lock_file = instance_double(File)
      job = described_class.allocate

      allow(job).to receive(:redis_lock_client).and_return(nil)
      allow(lock_file).to receive(:closed?).and_return(false)
      allow(File).to receive(:open).with(lock_path, 'a').and_return(lock_file)
      expect(lock_file).to receive(:flock).with(File::LOCK_EX | File::LOCK_NB).and_return(false)
      expect(lock_file).not_to receive(:flock).with(File::LOCK_UN)
      expect(FileUtils).not_to receive(:rm_f).with(lock_path)
      expect(lock_file).to receive(:close).once

      expect { job.write_lock(lock_path, wait_timeout: 0) { 'downloaded ok' } }
        .to raise_error("Could not acquire local lock for #{lock_path}")
    end
  end

  describe '#initialize_worker with a corrupt analysis.zip download' do
    # Seam choice: initialize_worker downloads via a plain inline URI.open (open-uri) call --
    # there is no separately-extractable "download" method to isolate, so the narrowest seam
    # that still exercises the *real* production retry/rescue/cleanup logic is to stub
    # URI.open to serve a local corrupt-zip fixture instead of hitting the network. Every
    # other step (write_lock, extract_archive, the Zip::Error/Zlib::Error rescue,
    # FileUtils.rm_rf(analysis_dir), and initialize_worker's own outer rescue) runs as the
    # real, unmodified production code.
    def build_zlib_corrupt_zip(path)
      # A default (DEFLATE) entry, not STORED: rubyzip does not verify CRCs on #extract (only
      # Analysis#seed_zip_error's own validator does, see spec/models/analysis_init_spec.rb),
      # so corrupting a STORED entry's bytes would extract silently. Zeroing bytes inside a
      # DEFLATE-compressed stream breaks the zlib inflate call itself.
      Zip::OutputStream.open(path) do |zos|
        zos.put_next_entry('data/seed.txt')
        zos.write('deterministic corrupt-zip payload text ' * 200)
      end
      content = File.binread(path)
      comp_start = content.index('data/seed.txt') + 'data/seed.txt'.length
      bytes = content.bytes
      20.times { |k| bytes[comp_start + k] = 0x00 }
      File.binwrite(path, bytes.pack('C*'))
      path
    end

    it 'fails on the first extraction attempt (no retries), reports zip corruption, and cleans up the partial analysis_dir' do
      Dir.mktmpdir('corrupt-zip-fixture') do |fixture_dir|
        corrupt_zip = build_zlib_corrupt_zip(File.join(fixture_dir, 'analysis.zip'))

        job = build_job
        allow(job).to receive(:sleep) # skip the real stagger/backoff sleeps around the download step
        allow(URI).to receive(:open) do |*_args, &blk|
          File.open(corrupt_zip, 'rb', &blk)
        end
        # This is the crux assertion: extraction must be attempted exactly once. If the
        # fix regresses to the old 3x retry, this expectation raises immediately on the
        # 2nd call (RSpec::Mocks::MockExpectationError), failing the example loudly.
        expect(job).to receive(:extract_archive).once.and_call_original

        analysis_dir = job.send(:analysis_dir)
        result = job.initialize_worker

        expect(result).to be false
        errs = job.instance_variable_get(:@intialize_worker_errs).join
        expect(errs).to match(/is corrupt and cannot be extracted/)
        expect(errs).not_to match(/failed 3 times/)
        expect(Dir.exist?(analysis_dir)).to be false
      end
    end
  end

  describe '#initialize_worker invalid initialize_worker_timeout correction (typo fix regression)' do
    it 'corrects a non-positive initialize_worker_timeout on the real Analysis instance (not a throwaway class variable) and proceeds without raising' do
      analysis.initialize_worker_timeout = 0
      analysis.save!

      job = build_job
      allow(job).to receive(:run_script_with_args)
      allow(job).to receive(:run_bundle_gems)
      allow(job).to receive(:write_lock) do |_lock_path, &_blk|
        receipt_file = File.join(job.send(:analysis_dir), 'analysis_zip.receipt')
        FileUtils.mkdir_p(job.send(:analysis_dir))
        File.write(receipt_file, Time.now.to_s)
        true
      end

      result = job.initialize_worker

      expect(result).to be true
      expect(job.instance_variable_get(:@intialize_worker_errs)).to be_empty
      expect(job.instance_variable_get(:@data_point).analysis.initialize_worker_timeout).to eq 28800
    end
  end
end
