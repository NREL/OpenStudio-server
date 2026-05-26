# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'zip'
require 'tmpdir'

RSpec.describe 'ProcessBulkUpload Jobs', type: :job do
  let!(:project) { FactoryBot.create(:project) }

  describe 'DjJobs::ProcessBulkUpload' do
    before :each do
      Analysis.destroy_all
    end

    it 'processes combined zip file, creates analysis, pulls out variables, starts analysis and cleans up zip file' do
      Dir.mktmpdir do |dir|
        # 1. Create a dummy formulation JSON
        formulation = {
          'analysis' => {
            'name' => 'Job Bulk Analysis A',
            'uuid' => SecureRandom.uuid,
            'problem' => {
              'analysis_type' => 'lhs',
              'workflow' => [
                {
                  'name' => 'dummy_measure',
                  'arguments' => [
                    {
                      'name' => 'dummy_arg',
                      'value' => 456,
                      'uuid' => SecureRandom.uuid
                    }
                  ],
                  'variables' => [
                    {
                      'name' => 'dummy_var',
                      'uuid' => SecureRandom.uuid,
                      'display_name' => 'Dummy Variable'
                    }
                  ]
                }
              ]
            }
          }
        }
        formulation_path = File.join(dir, 'analysis.json')
        File.write(formulation_path, formulation.to_json)

        # 2. Create the inner zip file containing the formulation
        inner_zip_path = File.join(dir, 'inner.zip')
        Zip::File.open(inner_zip_path, Zip::File::CREATE) do |zip|
          zip.add('analysis.json', formulation_path)
        end

        # 3. Create the combined zip file containing the inner zip
        combined_zip_path = File.join(dir, 'combined.zip')
        Zip::File.open(combined_zip_path, Zip::File::CREATE) do |zip|
          zip.add('inner.zip', inner_zip_path)
        end

        # Copy combined zip to a persistent test path because perform will delete it
        test_zip_path = File.join(dir, 'test_combined.zip')
        FileUtils.cp(combined_zip_path, test_zip_path)

        # Mock run_analysis
        allow_any_instance_of(Analysis).to receive(:run_analysis).and_return(true)

        # Instantiating and performing the DelayedJob
        job = DjJobs::ProcessBulkUpload.new(test_zip_path, project.id.to_s)
        job.perform

        # 4. Check if the Analysis was saved
        analysis = Analysis.where(name: 'Job Bulk Analysis A').first
        expect(analysis).not_to be_nil
        expect(analysis.project.id).to eq(project.id)
        expect(analysis.seed_zip).to be_present

        # 5. Check that measures and variables were extracted
        expect(analysis.measures.count).to eq(1)
        expect(analysis.variables.count).to eq(2) # 1 argument + 1 variable

        # 6. Verify combined zip was deleted
        expect(File.exist?(test_zip_path)).to be_falsey
      end
    end
  end

  describe 'ResqueJobs::ProcessBulkUpload' do
    it 'delegates to DjJobs::ProcessBulkUpload' do
      double_dj_job = double(DjJobs::ProcessBulkUpload)
      expect(DjJobs::ProcessBulkUpload).to receive(:new).with('/dummy/path.zip', 'proj-123').and_return(double_dj_job)
      expect(double_dj_job).to receive(:perform)

      ResqueJobs::ProcessBulkUpload.perform('/dummy/path.zip', 'proj-123')
    end
  end
end
