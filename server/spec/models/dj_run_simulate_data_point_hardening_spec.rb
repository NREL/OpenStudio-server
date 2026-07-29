# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'tmpdir'
require 'zip'

# Regression specs for the DjJobs::RunSimulateDataPoint#initialize_worker/#write_lock
# hardening: a competing worker's abandoned analysis_zip.lock (the holder crashed mid
# download/extract without ever writing analysis_zip.receipt) used to either deadlock a
# second worker for the full initialize_worker_timeout (default 8h) or, worse, let it fall
# through to a silent "return true" after the wait timed out. A corrupt analysis.zip was
# also retried 3x before failing, wasting time on a deterministic failure.
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

  def build_job
    described_class.new(data_point.id)
  end

  describe '#initialize_worker with a stale/abandoned analysis_zip.lock' do
    it 'returns false promptly (not true) when the lock holder disappears without ever writing a receipt' do
      analysis.initialize_worker_timeout = 20 # long enough that a real Timeout::Error cannot be what resolves this call
      analysis.save!

      job = build_job
      write_lock_file = File.join(job.send(:analysis_dir), 'analysis_zip.lock')
      receipt_file = File.join(job.send(:analysis_dir), 'analysis_zip.receipt')
      File.write(write_lock_file, 'held by a worker that is about to crash')

      # Simulate the original holder dying mid-extraction: its cleanup (fix #2, write_lock's
      # rescue) removes the lock file, but it never got far enough to write a receipt.
      remover = Thread.new do
        sleep 0.5
        FileUtils.rm_f(write_lock_file)
      end

      start = Time.now
      result = job.initialize_worker
      elapsed = Time.now - start
      remover.join

      expect(result).to be false
      expect(elapsed).to be < 10 # well under the 20s configured timeout: it did NOT wait it out
      expect(File.exist?(receipt_file)).to be false
    end

    it 'returns false and deletes the stale lock file when the wait genuinely times out' do
      analysis.initialize_worker_timeout = 2 # short timeout so the test itself stays fast
      analysis.save!

      job = build_job
      write_lock_file = File.join(job.send(:analysis_dir), 'analysis_zip.lock')
      receipt_file = File.join(job.send(:analysis_dir), 'analysis_zip.receipt')
      # Lock file present the whole time and no one ever removes it or writes a receipt --
      # a genuinely stuck/hung holder.
      File.write(write_lock_file, 'held by a worker that is stuck')

      start = Time.now
      result = job.initialize_worker
      elapsed = Time.now - start

      expect(result).to be false
      expect(elapsed).to be < 10 # proves it timed out at ~2s, not the old 28800s default
      expect(File.exist?(write_lock_file)).to be(false), 'stale lock must be removed so a future worker does not inherit the same wait'
      expect(File.exist?(receipt_file)).to be false
    end

    it 'still returns true when the receipt file appears before the lock disappears or the wait times out (non-broken-path regression)' do
      analysis.initialize_worker_timeout = 30
      analysis.save!

      job = build_job
      write_lock_file = File.join(job.send(:analysis_dir), 'analysis_zip.lock')
      receipt_file = File.join(job.send(:analysis_dir), 'analysis_zip.receipt')
      File.write(write_lock_file, 'held by a worker that is about to finish successfully')

      creator = Thread.new do
        sleep 0.3
        File.write(receipt_file, Time.now.to_s)
      end

      result = job.initialize_worker
      creator.join

      expect(result).to be true
      expect(File.exist?(write_lock_file)).to be(true), 'the successful holder (not the waiter) owns cleaning up the lock file'
    end
  end

  describe '#write_lock' do
    subject(:job) { described_class.allocate } # write_lock touches no @data_point/@sim_logger state, so a full DB-backed instance is unnecessary

    it 'removes the lock file (not just releasing the flock) when the protected block raises' do
      Dir.mktmpdir do |dir|
        lock_path = File.join(dir, 'analysis_zip.lock')

        expect { job.write_lock(lock_path) { raise 'boom' } }.to raise_error('boom')
        expect(File.exist?(lock_path)).to be false
      end
    end

    it 'leaves the lock file in place when the protected block succeeds (only the flock is released)' do
      Dir.mktmpdir do |dir|
        lock_path = File.join(dir, 'analysis_zip.lock')

        result = job.write_lock(lock_path) { 'downloaded ok' }

        expect(result).to eq 'downloaded ok'
        expect(File.exist?(lock_path)).to be true
      end
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
      analysis.initialize_worker_timeout = 0 # invalid; must be corrected to 28800 before the Timeout.timeout call reads it
      analysis.save!

      job = build_job
      write_lock_file = File.join(job.send(:analysis_dir), 'analysis_zip.lock')
      receipt_file = File.join(job.send(:analysis_dir), 'analysis_zip.receipt')
      # A pre-existing lock (no receipt yet) routes initialize_worker through the
      # "wait for receipt" branch, whose Timeout.timeout call is exactly the one that used
      # to read the never-corrected class variable's stale invalid value.
      File.write(write_lock_file, 'held by another worker')

      creator = Thread.new do
        sleep 0.3
        File.write(receipt_file, Time.now.to_s)
      end

      result = job.initialize_worker
      creator.join

      expect(result).to be true
      expect(job.instance_variable_get(:@intialize_worker_errs)).to be_empty
      expect(job.instance_variable_get(:@data_point).analysis.initialize_worker_timeout).to eq 28800
    end
  end

  describe '#extract_archive overwrite parameter (issue #858)' do
    # Use allocate to get a bare instance without hitting the database, then wire up a
    # minimal sim_logger so the logging calls inside extract_archive don't raise.
    subject(:job) { described_class.allocate.tap { |j| j.instance_variable_set(:@sim_logger, Logger.new(nil)) } }

    def build_test_zip(dir, entries)
      zip_path = File.join(dir, 'test.zip')
      Zip::OutputStream.open(zip_path) do |zos|
        entries.each do |name, content|
          zos.put_next_entry(name)
          zos.write(content)
        end
      end
      zip_path
    end

    it 'overwrites existing files when overwrite=true (the default), replacing stale content' do
      Dir.mktmpdir do |dest|
        stale_path = File.join(dest, 'measure.xml')
        File.write(stale_path, 'stale content')

        zip_dir = Dir.mktmpdir('extract-archive-overwrite')
        zip_path = build_test_zip(zip_dir, { 'measure.xml' => 'fresh content' })

        job.send(:extract_archive, zip_path, dest, true)

        expect(File.read(stale_path)).to eq 'fresh content'
        FileUtils.rm_rf(zip_dir)
      end
    end

    it 'skips existing files when overwrite=false, preserving their content' do
      Dir.mktmpdir do |dest|
        existing_path = File.join(dest, 'measure.xml')
        File.write(existing_path, 'original content')

        zip_dir = Dir.mktmpdir('extract-archive-no-overwrite')
        zip_path = build_test_zip(zip_dir, { 'measure.xml' => 'new content' })

        job.send(:extract_archive, zip_path, dest, false)

        expect(File.read(existing_path)).to eq 'original content'
        FileUtils.rm_rf(zip_dir)
      end
    end

    it 'extracts new files regardless of overwrite setting' do
      Dir.mktmpdir do |dest|
        zip_dir = Dir.mktmpdir('extract-archive-new-file')
        zip_path = build_test_zip(zip_dir, { 'new_file.txt' => 'new content' })

        job.send(:extract_archive, zip_path, dest)

        expect(File.read(File.join(dest, 'new_file.txt'))).to eq 'new content'
        FileUtils.rm_rf(zip_dir)
      end
    end
  end
end
