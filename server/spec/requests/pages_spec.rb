require 'rails_helper'

describe "Pages Exist", :type => :feature do
  it "HomePage" do
    visit '/'

    expect(page).to have_content 'Home Projects Analyses Example Analysis Nodes Admin About'
  end

  it "Home and Status Page" do
    get '/'
    expect(response).to be_success
    expect(response.body).to have_content 'Home Projects Analyses Example Analysis Nodes Admin About'

    get '/status.json'
    expect(response).to be_success
    expect(json['status']['awake']).not_to be_nil
  end
end