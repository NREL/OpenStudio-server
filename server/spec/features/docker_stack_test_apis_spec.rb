# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

#################################################################################
# To Run this test manually:
#
#   start a server stack with /spec added and ssh into the Web container
#   you may need to ADD the spec folder in the Dockerfile
#   >ruby /opt/openstudio/bin/openstudio_meta install_gems
#   >bundle install --with development test
#   >rspec spec/features/docker_stack_test_apis_spec.rb
#
#################################################################################

require 'rails_helper'
require 'rest-client'
require 'json'
require 'csv'

# Set obvious paths for start-local & run-analysis invocation
RUBY_CMD = 'ruby'
BUNDLE_CMD = 'bundle exec ruby'

# Docker tests have these hard coded paths
META_CLI = File.absolute_path('/opt/openstudio/bin/openstudio_meta')
PROJECT = File.absolute_path(File.join(File.dirname(__FILE__), '../files/'))
HOST = '127.0.0.1'

puts "Project folder is: #{PROJECT}"
puts "META_CLI is: #{META_CLI}"
puts "App host is: http://#{HOST}"

# the actual tests
RSpec.describe 'TestAPIs', type: :feature do
  before :all do
    @host = HOST
    @project = PROJECT
    @meta_cli = META_CLI
    @ruby_cmd = RUBY_CMD
    @bundle_cmd = BUNDLE_CMD

    options = { hostname: "http://#{@host}" }
    #APP_CONFIG['os_server_host_url'] = options[:hostname]
  end

  it 'run api_tests', :api_tests do

    sleep(1)
    puts 'access main GUI page'
    a = RestClient.get "http://#{@host}"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.body).not_to include "Error"
    expect(a.body).to include "OpenStudio Cloud Management Console"
    
    sleep(1)
    puts 'remove any existing projects'
    a = RestClient.get "http://#{@host}/projects.json"
    a = JSON.parse(a, symbolize_names: true)
    a.each do |project|
        sleep(1)
        id = project[:_id]
        puts "removing existing project id: #{id}"
        begin
            RestClient.delete "http://#{@host}/projects/#{id}"
        rescue RestClient::ExceptionWithResponse => err
            case err.http_code
            when 301, 302, 307
                puts '   redirecting after delete'
            end
        end
    end
    
    sleep(1)
    puts 'check there are no projects'
    a = RestClient.get "http://#{@host}/projects.json"
    a = JSON.parse(a, symbolize_names: true)
    expect(a).to be_empty
    
    sleep(1)
    puts 'check that there are no analyses'
    a = RestClient.get "http://#{@host}/analyses.json"
    a = JSON.parse(a, symbolize_names: true)
    expect(a).to be_empty
    
    sleep(1)
    puts 'restore database'
    URL = "http://#{@host}/admin/restore_database"
    file = File.new("/opt/openstudio/server/spec/files/mongodump_1651085721.tar.gz", "rb")
        begin
            RestClient.post(URL, {:file => file} )
        rescue RestClient::ExceptionWithResponse => err
            case err.http_code
            when 301, 302, 307
                puts '   redirecting after restore'
            end
        end
    file.close
    
    sleep(1)
    puts 'check there is one expected analyses'
    a = RestClient.get "http://#{@host}/analyses.json"
    a = JSON.parse(a, symbolize_names: true)
    expect(a).not_to be_empty
    expect(a.size).to eq(1)
    analysis = a[0]
    analysis_id = analysis[:_id]
    expect(analysis_id).to eq("86a529c9-8429-41e8-bca5-52b2628c8ff9")

    sleep(1)
    puts 'check the status.json'
    a = RestClient.get "http://#{@host}/analyses/status.json"
    expect(a.headers[:status]).to eq("200 OK")
    a = JSON.parse(a, symbolize_names: true)
    expect(a).not_to be_empty
    expect(a.size).to eq(1)
    expect(a[:analysis][:status]).to eq("completed")
    expect(a[:analysis][:total_datapoints]).to eq(4)
    
    sleep(1)
    puts 'check the default significant digits'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.body).to include "Obj Func Significant Digits"
    expect(a.body).to include "20.235"
    expect(a.body).to include "75.772"
    expect(a.body).to include "50.381"
    
    sleep(1)
    puts 'change the significant digits to 4'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9?significant_digits=4&commit=Update"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.body).to include "Obj Func Significant Digits"
    expect(a.body).to include "20.2345"
    expect(a.body).to include "75.7723"
    expect(a.body).to include "50.3806"
    
    sleep(1)
    puts 'test download CSV metadata'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/variables/download_variables.csv"
    expect(a.size).to be >(8000)
    expect(a.size).to be <(10000)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("text/csv; charset=iso-8859-1")
    expect(a.headers[:content_disposition]).to include("SEB_calibration_NSGA_2013_metadata.csv")
    a = CSV.parse(a)
    expect(a).not_to be_empty
    expect(a[0][0]).to eq("display_name")
    expect(a.size).to eq(33)

    sleep(1)
    puts 'test download CSV results'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/download_data.csv?export=true"
    expect(a.size).to be >(4000)
    expect(a.size).to be <(6000)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("text/csv; charset=iso-8859-1")
    expect(a.headers[:content_disposition]).to include("SEB_calibration_NSGA_2013.csv")
    a = CSV.parse(a)
    expect(a).not_to be_empty
    expect(a[0][0]).to eq("name")
    expect(a.size).to eq(5)

    sleep(1)
    puts 'test download RData metadata'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/variables/download_variables.rdata"
    expect(a).not_to be_empty
    expect(a.size).to be >(1500)
    expect(a.size).to be <(2500)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("application/rdata; header=present")
    expect(a.headers[:content_disposition]).to include("SEB_calibration_NSGA_2013_metadata.RData")

    sleep(1)
    puts 'test download RData results'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/download_data.rdata?export=true"
    expect(a).not_to be_empty
    expect(a.size).to be >(1500)
    expect(a.size).to be <(2500)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("application/rdata; header=present")
    expect(a.headers[:content_disposition]).to include("SEB_calibration_NSGA_2013_results.RData")

    sleep(1)
    puts 'test analysis_data JSON'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/analysis_data.json"
    expect(a).not_to be_empty
    expect(a.size).to be >(22000)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("application/json; charset=utf-8")
    a = JSON.parse(a, symbolize_names: true)
    #should have 32 variables with any_of :export, :visualize, :pivot true
    expect(a[:variables].size).to eq(32)
    count = 0
    a[:variables].each_with_index do |(key, value), i|
        if value[:visualize] == true
            count += 1
        end
    end
    #only 23 variables with visualize true
    expect(count).to eq(23)
    #should be 4 datapoints
    expect(a[:data].size).to eq(4)
    
    sleep(1)
    puts 'test download selected parallel coordinate plot datapoints in CSV'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/download_selected_datapoints.csv?dps=0c0f61a0-58d7-43ab-a757-de491e272c38,298429ea-82b2-4ec3-85cb-6cf83bfcddd8,068a2732-45c0-4097-b645-0342720712d2"
    expect(a).not_to be_empty
    expect(a.size).to be >(3500)
    expect(a.size).to be <(4500)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("text/csv; charset=iso-8859-1")
    expect(a.headers[:content_disposition]).to include("SEB_calibration_NSGA_2013.csv")
    a = CSV.parse(a)
    expect(a).not_to be_empty
    expect(a[0][0]).to eq("name")
    expect(a.size).to eq(4)

    sleep(1)
    puts 'download selected pareto plot datapoints in CSV'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/download_selected_datapoints.csv?dps=0c0f61a0-58d7-43ab-a757-de491e272c38%2C511a2d68-555f-40be-8f4c-8559a98f51fc"
    expect(a).not_to be_empty
    expect(a.size).to be >(2500)
    expect(a.size).to be <(3500)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("text/csv; charset=iso-8859-1")
    expect(a.headers[:content_disposition]).to include("SEB_calibration_NSGA_2013.csv")
    a = CSV.parse(a)
    expect(a).not_to be_empty
    expect(a[0][0]).to eq("name")
    expect(a.size).to eq(3)

    sleep(1)
    puts 'download selected parallel coordinate plot datapoints in RDATA'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/download_selected_datapoints.rdata?dps=0c0f61a0-58d7-43ab-a757-de491e272c38,298429ea-82b2-4ec3-85cb-6cf83bfcddd8,068a2732-45c0-4097-b645-0342720712d2"
    expect(a).not_to be_empty
    expect(a.size).to be >(1000)
    expect(a.size).to be <(2000)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("application/rdata; header=present")
    expect(a.headers[:content_disposition]).to include("SEB_calibration_NSGA_2013_results.RData")

    sleep(1)
    puts 'download selected pareto plot datapoints in RDATA'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/download_selected_datapoints.rdata?dps=0c0f61a0-58d7-43ab-a757-de491e272c38%2C511a2d68-555f-40be-8f4c-8559a98f51fc"
    expect(a).not_to be_empty
    expect(a.size).to be >(1000)
    expect(a.size).to be <(1500)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("application/rdata; header=present")
    expect(a.headers[:content_disposition]).to include("SEB_calibration_NSGA_2013_results.RData")
  
    sleep(1)
    puts 'delete project'
    a = RestClient.get "http://#{@host}/projects.json"
    a = JSON.parse(a, symbolize_names: true)
    expect(a).not_to be_empty
    projects = a[0]
    projects_id = projects[:_id]
    expect(projects_id).to eq("0a77cd57-359c-4e3c-b8e8-d49311de0719")
    begin
        RestClient.delete "http://#{@host}/projects/0a77cd57-359c-4e3c-b8e8-d49311de0719"
    rescue RestClient::ExceptionWithResponse => err
        case err.http_code
        when 301, 302, 307
            puts '   redirecting after delete'
        end
    end
    a = RestClient.get "http://#{@host}/projects.json"
    a = JSON.parse(a, symbolize_names: true)
    expect(a).to be_empty

    puts 'check admin page for error'

    a = RestClient.get "http://#{@host}/admin"
    expect(a.body).not_to include "Error"
  end    
end
