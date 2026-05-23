# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'
require 'zip'
require 'tmpdir'

RSpec.describe 'Analyses Batch Create API', type: :request do
  let!(:project) { FactoryBot.create(:project) }

  describe 'POST /projects/:project_id/analyses/batch_create.json' do
    it 'creates analyses and starts them from a combined zip' do
      Dir.mktmpdir do |dir|
        # 1. Create a dummy formulation JSON
        formulation = {
          analysis: {
            name: 'Bulk Analysis A',
            uuid: SecureRandom.uuid,
            problem: {
              analysis_type: 'lhs'
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

        # 4. Perform the post request
        uploaded_file = Rack::Test::UploadedFile.new(combined_zip_path, 'application/zip')
        
        # Mock analysis start to avoid delayed job queues in test
        allow_any_instance_of(Analysis).to receive(:run_analysis).and_return(true)

        post "/projects/#{project.id}/analyses/batch_create.json", params: { file: uploaded_file }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('success')
        expect(json['created'].size).to eq(1)

        # 5. Check if the Analysis was saved
        analysis = Analysis.where(name: 'Bulk Analysis A').first
        expect(analysis).not_to be_nil
        expect(analysis.project.id).to eq(project.id)
        expect(analysis.seed_zip).to be_present
      end
    end
  end
end
