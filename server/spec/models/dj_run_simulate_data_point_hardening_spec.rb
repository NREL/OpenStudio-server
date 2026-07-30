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

    it 'fails terminally after bounded validation attempts (no 12x retry), reports zip corruption, and cleans up the partial analysis_dir' do
      Dir.mktmpdir('corrupt-zip-fixture') do |fixture_dir|
        corrupt_zip = build_zlib_corrupt_zip(File.join(fixture_dir, 'analysis.zip'))
        serve_count = 0

        job = build_job
        allow(job).to receive(:sleep) # skip the real stagger/backoff sleeps around the download step
        allow(URI).to receive(:open) do |*_args, &blk|
          serve_count += 1
          File.open(corrupt_zip, 'rb', &blk)
        end
        # Since the issue #857 download-validation fix, deterministic corruption is
        # caught BEFORE extraction: the downloaded bytes fail validation on
        # 3 consecutive attempts (distinguishing corrupt-at-rest from a transiently
        # truncated transfer, which heals on retry) and escalate to the same terminal
        # CorruptAnalysisZip path. Extraction must never run against corrupt bytes,
        # and the old blind 12x download retry must not resurrect.
        expect(job).not_to receive(:extract_archive)

        analysis_dir = job.send(:analysis_dir)
        result = job.initialize_worker

        expect(result).to be false
        expect(serve_count).to eq 3
        errs = job.instance_variable_get(:@intialize_worker_errs).join
        expect(errs).to match(/is corrupt and cannot be extracted/)
        expect(errs).not_to match(/Could not download the analysis zip after/)
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

  # Regression specs for the analysis-zip corruption on shared-filesystem (NFS/k8s)
  # deployments (issue #857). Three distinct defects, three seams:
  #   1. extract_archive used the Zip::File.open block form with ::Zip.sort_entries = true;
  #      the implicit close called commit, which REWRITES the archive in place (temp file +
  #      rename) whenever sorting reordered the entry list. On the shared analysis dir that
  #      rewrite races other workers downloading/extracting the same file.
  #   2. The analysis.zip download wrote straight to its final shared path with no
  #      integrity check, so a truncated/mid-rewrite fetch was extracted as-is and
  #      escalated to a terminal CorruptAnalysisZip datapoint failure.
  #   3. A worker that raced past the outer receipt check re-downloaded and re-extracted
  #      the zip even when the receipt appeared before it acquired the lock, overwriting
  #      content other datapoints were actively reading (the herd effect: N workers, N
  #      serial re-downloads).
  describe '#extract_archive read-only behavior (issue #857)' do
    subject(:job) { described_class.allocate.tap { |j| j.instance_variable_set(:@sim_logger, Logger.new(nil)) } }

    # Entries deliberately NOT in sorted order: that is what makes rubyzip's close
    # decide commit_required? and rewrite the file when sort_entries is set.
    def build_unsorted_zip(path)
      Zip::OutputStream.open(path) do |zos|
        zos.put_next_entry('zzz_last.txt')
        zos.write('z' * 100)
        zos.put_next_entry('aaa_first.txt')
        zos.write('a' * 100)
      end
      path
    end

    it 'leaves the archive byte-identical after extraction' do
      Dir.mktmpdir do |dir|
        zip_path = build_unsorted_zip(File.join(dir, 'analysis.zip'))
        before_md5 = Digest::MD5.file(zip_path).hexdigest
        dest = File.join(dir, 'extract_dest')
        FileUtils.mkdir_p(dest)

        job.send(:extract_archive, zip_path, dest)

        expect(Digest::MD5.file(zip_path).hexdigest).to eq(before_md5), 'extract_archive must never modify the archive it reads'
        expect(File.read(File.join(dest, 'aaa_first.txt'))).to eq('a' * 100)
        expect(File.read(File.join(dest, 'zzz_last.txt'))).to eq('z' * 100)
      end
    end
  end

  # Regression specs for issue #858: extract_archive declared an overwrite parameter but
  # never checked it -- every existing file was skipped unconditionally. A worker killed
  # mid-extract (rollout restart) leaves partial/stale files in the shared analysis dir;
  # the next worker's extract must replace them, or OpenStudio's BCLMeasure loader chokes
  # on the stale measure.xml ("could not be read as XML data").
  describe '#extract_archive overwrite behavior (issue #858)' do
    subject(:job) { described_class.allocate.tap { |j| j.instance_variable_set(:@sim_logger, Logger.new(nil)) } }

    def build_measure_zip(path, xml)
      Zip::OutputStream.open(path) do |zos|
        zos.put_next_entry('measures/m1/measure.xml')
        zos.write(xml)
      end
      path
    end

    it 'replaces a pre-existing stale file with the archive contents by default' do
      Dir.mktmpdir do |dir|
        zip_path = build_measure_zip(File.join(dir, 'analysis.zip'), '<measure>fresh</measure>')
        dest = File.join(dir, 'dest')
        stale_path = File.join(dest, 'measures/m1/measure.xml')
        FileUtils.mkdir_p(File.dirname(stale_path))
        File.write(stale_path, '<measure>stale, from a worker killed mid-ext')

        job.send(:extract_archive, zip_path, dest)

        expect(File.read(stale_path)).to eq('<measure>fresh</measure>'), 'overwrite defaults to true: stale pre-existing files must be replaced, not skipped'
      end
    end

    it 'keeps a pre-existing file when overwrite is false' do
      Dir.mktmpdir do |dir|
        zip_path = build_measure_zip(File.join(dir, 'analysis.zip'), '<measure>fresh</measure>')
        dest = File.join(dir, 'dest')
        existing_path = File.join(dest, 'measures/m1/measure.xml')
        FileUtils.mkdir_p(File.dirname(existing_path))
        File.write(existing_path, '<measure>keep me</measure>')

        job.send(:extract_archive, zip_path, dest, false)

        expect(File.read(existing_path)).to eq('<measure>keep me</measure>')
      end
    end
  end

  describe '#initialize_worker with a truncated analysis.zip download (issue #857 serving race)' do
    def build_valid_zip(path)
      Zip::OutputStream.open(path) do |zos|
        zos.put_next_entry('measures/m1/measure.xml')
        zos.write('<measure>deterministic payload</measure>' * 50)
      end
      path
    end

    it 'validates each fetch, retries truncated bytes, and only extracts verified bytes' do
      Dir.mktmpdir('truncated-zip-fixture') do |fixture_dir|
        valid_bytes = File.binread(build_valid_zip(File.join(fixture_dir, 'analysis.zip')))
        truncated_bytes = valid_bytes[0...-30] # cuts the end-of-central-directory record
        serve_count = 0

        job = build_job
        allow(job).to receive(:sleep) # skip the real stagger/backoff sleeps
        allow(URI).to receive(:open) do |*_args, &blk|
          serve_count += 1
          blk.call(StringIO.new(serve_count < 3 ? truncated_bytes : valid_bytes))
        end
        fake_client = instance_double(OsHttp::Client)
        allow(fake_client).to receive(:get).and_return(OsHttp::Response.new(200, '{}'))
        allow(OsHttp).to receive(:client).and_return(fake_client)

        result = job.initialize_worker

        expect(result).to be(true), 'a transiently-truncated download must be retried, not escalated to a terminal corrupt-zip failure'
        expect(serve_count).to be >= 3
        download_file = File.join(job.send(:analysis_dir), 'analysis.zip')
        expect(File.binread(download_file)).to eq(valid_bytes), 'only verified bytes may be placed at the shared analysis.zip path'
        expect(File.exist?(File.join(job.send(:analysis_dir), 'analysis_zip.receipt'))).to be true
      end
    end
  end

  describe '#lock_abandoned? NFS-safe probe (issue #857 follow-up)' do
    subject(:job) { described_class.allocate.tap { |j| j.instance_variable_set(:@sim_logger, Logger.new(nil)) } }

    # Over NFSv4 flock is emulated with byte-range locks: an exclusive probe on a
    # read-only fd raises Errno::EBADF (local filesystems allow it, which is why
    # this never failed in CI). An unrescued EBADF crashes the waiter; rescuing it
    # as "abandoned" is worse - it deletes a LIVE holder's lock, letting the next
    # worker re-create the lock on a new inode and initialize the same analysis_dir
    # concurrently. The only safe reading of an indeterminate probe is "held".
    it 'returns false instead of raising when the flock probe fails with EBADF (NFSv4 read-only fd)' do
      Dir.mktmpdir do |dir|
        lock_path = File.join(dir, 'analysis_zip.lock')
        File.write(lock_path, 'held by a live worker on another node')
        allow_any_instance_of(File).to receive(:flock).and_raise(Errno::EBADF)

        result = nil
        expect { result = job.send(:lock_abandoned?, lock_path) }.not_to raise_error
        expect(result).to be false
      end
    end

    it 'does not report a held lock as abandoned' do
      Dir.mktmpdir do |dir|
        lock_path = File.join(dir, 'analysis_zip.lock')
        holder = File.open(lock_path, 'a')
        holder.flock(File::LOCK_EX)

        expect(job.send(:lock_abandoned?, lock_path)).to be false
      ensure
        holder.flock(File::LOCK_UN)
        holder.close
      end
    end

    it 'reports an unheld lock file as abandoned' do
      Dir.mktmpdir do |dir|
        lock_path = File.join(dir, 'analysis_zip.lock')
        File.write(lock_path, 'holder died without cleanup')

        expect(job.send(:lock_abandoned?, lock_path)).to be true
      end
    end
  end

  describe '#initialize_worker receipt re-check inside the lock (issue #857 herd re-download)' do
    it 'skips download/extract when the receipt appeared while queueing for the lock' do
      job = build_job
      receipt_file = File.join(job.send(:analysis_dir), 'analysis_zip.receipt')

      # Deterministic reproduction of the race: this worker passed the outer receipt
      # check (no receipt yet), and the init winner wrote the receipt just before this
      # worker acquired the flock. and_wrap_original interposes at exactly that
      # boundary; the real write_lock (real flock, real block) still runs.
      allow(job).to receive(:write_lock).and_wrap_original do |orig, path, &blk|
        File.write(receipt_file, 'winner finished while we queued for the lock')
        orig.call(path, &blk)
      end
      expect(URI).not_to receive(:open)

      result = job.initialize_worker

      expect(result).to be true
      expect(File.read(receipt_file)).to eq 'winner finished while we queued for the lock'
    end
  end
end
