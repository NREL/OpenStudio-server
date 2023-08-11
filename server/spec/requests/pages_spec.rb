# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

RSpec.describe 'Pages Exist', type: :feature do
  it 'HomePage' do
    visit '/'

    expect(page).to have_content 'OpenStudio Cloud Management Console'
  end

  describe 'GET /status.json' do
    before { get "/status.json" }

    it 'get status' do
      expect(json).not_to be_empty
      expect(json['status']['awake']).not_to be_nil
    end
  end

  it 'Admin page' do
    visit '/admin'
    expect(page).to have_content 'Version of OpenStudio'
    expect(page).not_to have_content 'Error'
  end

  it 'Accesses the API over host using selenium', js: true, depends_gecko: true do
    visit '/'
    host = "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"

    expect(host).to match /\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}:\d{2,5}/
    a = RestClient.get "http://#{host}"

    expect(a.body).to have_content 'OpenStudio Cloud Management Console'
  end
end
