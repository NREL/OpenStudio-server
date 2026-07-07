# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'tmpdir'

# Regression specs for https://github.com/NatLabRockies/OpenStudio-server/issues/841 -
# corrupt seed.zip uploads must be rejected with a 422 and a descriptive error instead
# of being accepted and later stranding the analysis in a failed InitializeAnalysis job.
RSpec.describe 'Analyses seed zip upload', type: :request do
  before :all do
    Project.destroy_all
    FactoryBot.create(:project_with_analyses, analyses_count: 1)

    @project = Project.first
    @analysis = @project.analyses.first
    @tmp_dir = Dir.mktmpdir('analyses-upload-spec')
  end

  after :all do
    # Destroy factory data so paperclip deletes the uploaded seed zips and prunes the
    # emptied assets/analyses directory. In the docker CI job this spec runs as root
    # inside the web container while the live app runs as an unprivileged user - a
    # leftover root-owned assets/analyses dir makes every later upload fail with
    # EACCES, and leftover projects break docker_stack_test_apis_spec assertions.
    Project.destroy_all
    FileUtils.rm_rf(@tmp_dir)
  end

  describe 'POST /analyses/:id/upload' do
    it 'rejects a file that is not a zip archive with 422 and a descriptive error' do
      # Regression: issue #841 - corrupt uploads were accepted and only failed later in
      # ResqueJobs::InitializeAnalysis, permanently stranding the analysis
      corrupt_path = File.join(@tmp_dir, 'corrupt_seed.zip')
      File.binwrite(corrupt_path, 'this is not a zip archive at all')

      post "/analyses/#{@analysis.id}/upload.json",
           params: { file: Rack::Test::UploadedFile.new(corrupt_path, 'application/zip') }

      expect(response).to have_http_status(422)
      expect(json['error_message']).to match(/not a valid ZIP archive/)
    end

    it 'rejects a truncated zip archive with 422 and a descriptive error' do
      # Regression: issue #841 - partial/interrupted uploads keep the 'PK' magic bytes,
      # so a content-type check alone does not catch them
      valid_bytes = File.binread("#{Rails.root}/spec/files/batch_datapoints/example_csv.zip")
      truncated_path = File.join(@tmp_dir, 'truncated_seed.zip')
      File.binwrite(truncated_path, valid_bytes[0, valid_bytes.length / 2])

      post "/analyses/#{@analysis.id}/upload.json",
           params: { file: Rack::Test::UploadedFile.new(truncated_path, 'application/zip') }

      expect(response).to have_http_status(422)
      expect(json['error_message']).to match(/not a valid ZIP archive/)
    end

    it 'accepts a valid seed zip' do
      # Validates: the new upload validation must not reject healthy seed zips
      # NOTE: on Windows dev machines this example fails because rack-test 2.2.0 builds
      # the multipart body with a text-mode read that truncates at the first 0x1A byte;
      # it passes on Linux (CI). Analysis.seed_zip_error accepting this exact fixture is
      # also covered directly in spec/models/analysis_init_spec.rb.
      post "/analyses/#{@analysis.id}/upload.json",
           params: { file: Rack::Test::UploadedFile.new(
             "#{Rails.root}/spec/files/batch_datapoints/example_csv.zip", 'application/zip'
           ) }

      expect(response).to have_http_status(:created)
      expect(@analysis.reload.seed_zip.original_filename).to eq 'example_csv.zip'
    end
  end
end
