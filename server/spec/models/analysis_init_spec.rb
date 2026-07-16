# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'tmpdir'

# Regression specs for https://github.com/NatLabRockies/OpenStudio-server/issues/841 -
# a corrupt seed.zip must fail fast (no pointless retries of a deterministic failure),
# leave the analysis in a terminal 'failed' state visible to API clients, and be
# detectable before the InitializeAnalysis job ever runs.
RSpec.describe Analysis, type: :model do
  before :all do
    destroy_projects_inline
    @analysis = FactoryBot.create(:analysis)
    @tmp_dir = Dir.mktmpdir('analysis-init-spec')
  end

  after :all do
    # Destroy factory data so paperclip deletes the seed zip files and prunes the
    # emptied assets/analyses directory. In the docker CI job this spec runs as root
    # inside the web container while the live app runs as an unprivileged user - a
    # leftover root-owned assets/analyses dir makes every later upload fail with
    # EACCES, and leftover projects break docker_stack_test_apis_spec assertions.
    # Inline so the DeleteAnalysis rm_rf cannot fire mid-run of a later spec.
    destroy_projects_inline
    FileUtils.rm_rf(@tmp_dir)
  end

  def build_valid_zip(path)
    Zip::OutputStream.open(path) do |zos|
      zos.put_next_entry('data/seed.txt')
      zos.write 'seed zip payload for crc check'
    end
    path
  end

  # STORED (uncompressed) entry so the byte flip below corrupts the payload without
  # breaking the zip structure - the archive still opens and extracts, only a CRC
  # comparison can catch the corruption
  def build_crc_corrupt_zip(path)
    Zip::OutputStream.open(path) do |zos|
      zos.put_next_entry('data/seed.txt', nil, nil, Zip::Entry::STORED)
      zos.write 'seed zip payload for crc check'
    end
    content = File.binread(path)
    File.binwrite(path, content.sub('seed zip payload', 'SEED ZIP PAYLOAD'))
    path
  end

  # Cut the archive in half: the 'PK' magic bytes survive (so content-type checks pass)
  # but the central directory is gone, which is what a partial/interrupted upload looks like
  def build_truncated_zip(path)
    build_valid_zip(path)
    content = File.binread(path)
    File.binwrite(path, content[0, content.length / 2])
    path
  end

  def attach_truncated_seed_zip(analysis)
    truncated = build_truncated_zip(File.join(@tmp_dir, 'truncated_seed.zip'))
    analysis.seed_zip = File.new(truncated)
    analysis.save!
    analysis
  end

  describe '.seed_zip_error' do
    it 'returns nil for a valid zip' do
      # Validates: upload validation must not reject healthy seed zips
      path = build_valid_zip(File.join(@tmp_dir, 'valid.zip'))
      expect(Analysis.seed_zip_error(path)).to be_nil
    end

    it 'returns nil for the reference seed zip fixture' do
      # Validates: the real fixture used across the suite passes validation
      expect(Analysis.seed_zip_error("#{Rails.root}/spec/files/batch_datapoints/example_csv.zip")).to be_nil
    end

    it 'reports a file that is not a zip archive' do
      # Regression: issue #841 - garbage uploads were accepted and only failed in InitializeAnalysis
      path = File.join(@tmp_dir, 'garbage.zip')
      File.binwrite(path, 'this is not a zip archive at all')
      expect(Analysis.seed_zip_error(path)).to match(/not a valid ZIP archive/)
    end

    it 'reports a truncated zip archive' do
      # Regression: issue #841 - partially uploaded seed zips were accepted and only failed in InitializeAnalysis
      path = build_truncated_zip(File.join(@tmp_dir, 'truncated.zip'))
      expect(Analysis.seed_zip_error(path)).to match(/not a valid ZIP archive/)
    end

    it 'reports an entry whose payload does not match its CRC' do
      # Validates: bit-rot that keeps the zip structure intact is still caught (rubyzip
      # 2.x does not verify CRCs on extract, so this is the only line of defense)
      path = build_crc_corrupt_zip(File.join(@tmp_dir, 'crc_corrupt.zip'))
      expect(Analysis.seed_zip_error(path)).to match(/entry 'data\/seed\.txt' is corrupt \(CRC mismatch\)/)
    end

    it 'rejects an archive that inflates past the size cap' do
      # Validates: validation must not inflate unbounded data in the request path - a
      # zip bomb would otherwise pin a web worker (PR #844 review)
      stub_const('Analysis::SEED_ZIP_MAX_INFLATED_BYTES', 10)
      path = build_valid_zip(File.join(@tmp_dir, 'inflates_past_cap.zip'))
      expect(Analysis.seed_zip_error(path)).to eq 'seed zip inflates to more than 10 bytes'
    end

    it 'rejects an archive with more file entries than the cap' do
      # Validates: entry-count cap bounds validation work in the request path (PR #844 review)
      stub_const('Analysis::SEED_ZIP_MAX_ENTRIES', 1)
      path = File.join(@tmp_dir, 'too_many_entries.zip')
      Zip::OutputStream.open(path) do |zos|
        zos.put_next_entry('a.txt')
        zos.write 'a'
        zos.put_next_entry('b.txt')
        zos.write 'b'
      end
      expect(Analysis.seed_zip_error(path)).to eq 'seed zip contains more than 1 file entries'
    end
  end

  describe '#run_initialization with a corrupt seed zip' do
    it 'fails on the first attempt without retrying and cleans up partial extraction' do
      # Regression: issue #841 - corrupt zips were retried 3 times ("Extraction of the
      # seed.zip file failed 3 times with error zlib error while inflating") even though
      # the failure is deterministic
      attach_truncated_seed_zip(@analysis)
      FileUtils.mkdir_p(@analysis.shared_directory_path)
      File.write(File.join(@analysis.shared_directory_path, 'partial_file.txt'), 'stale partial extraction')

      expect(@analysis).to receive(:extract_archive).once.and_call_original
      expect { @analysis.run_initialization }.to raise_error(/corrupt and cannot be extracted/)
      expect(Dir.exist?(@analysis.shared_directory_path)).to be(false), 'partial extraction dir must be removed so a re-run does not skip-and-reuse stale files'
    end

    it 'still retries transient extraction errors up to 3 attempts' do
      # Validates: fail-fast on corrupt zips must not remove the retry that papers over
      # transient IO failures (e.g. NFS hiccups on the osdata volume)
      attempts = 0
      allow(@analysis).to receive(:extract_archive) do
        attempts += 1
        raise Errno::EIO, 'transient io failure' if attempts < 3
      end

      expect { @analysis.run_initialization }.not_to raise_error
      expect(attempts).to eq(3), 'transient errors should be retried until the 3-attempt cap'
    end
  end

  describe '#fail_job!' do
    it 'marks the newest job failed so the analysis reaches a terminal state' do
      # Regression: issue #841 - analyses with failed initialization sat in 'queued'
      # forever with no API-visible failure state
      job = Job.new_job(@analysis.id, 'batch_run', 0, {})

      @analysis.fail_job!('seed zip is corrupt')

      expect(job.reload.status).to eq 'failed'
      expect(job.status_message).to eq 'seed zip is corrupt'
      expect(@analysis.reload.status_message).to eq 'seed zip is corrupt'
      expect(@analysis.status).to eq 'failed'
    end
  end

  describe 'ResqueJobs::InitializeAnalysis.perform with a corrupt seed zip' do
    it 'marks the analysis failed and re-raises so Resque records the failure' do
      # Regression: issue #841 - InitializeAnalysis had no error handling; failures left
      # the analysis stuck and RunAnalysis was silently never enqueued
      attach_truncated_seed_zip(@analysis)
      job = Job.new_job(@analysis.id, 'batch_run', 0, {})

      expect do
        ResqueJobs::InitializeAnalysis.perform('batch_run', @analysis.id, job.id)
      end.to raise_error(/corrupt and cannot be extracted/)

      expect(job.reload.status).to eq 'failed'
      expect(job.status_message).to match(/Analysis initialization failed: Seed zip for analysis #{@analysis.id} is corrupt/)
      expect(@analysis.reload.status).to eq 'failed'
    end
  end
end
