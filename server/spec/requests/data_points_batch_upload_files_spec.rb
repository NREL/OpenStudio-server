require 'rails_helper'

RSpec.describe 'DataPoints Batch Upload Files API', type: :request do
  let!(:analysis) { FactoryBot.create(:analysis) }
  let!(:data_point) { FactoryBot.create(:data_point, analysis: analysis) }

  describe 'POST /data_points/:id/batch_upload_files.json' do
    let(:valid_params) do
      {
        files: [
          {
            display_name: 'test_file.osa',
            type: 'application/zip',
            attachment: Base64.encode64('dummy content')
          }
        ]
      }
    end

    it 'uploads files and returns summary' do
      post "/data_points/#{data_point.id}/batch_upload_files.json", params: valid_params, as: :json
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['saved']).to eq(1)
      expect(json['total']).to eq(1)
    end
  end
end
