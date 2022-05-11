# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

#################################################################################
# To Run this test manually:
#
#   start a server stack with /spec added and ssh into the Web container
#   >ruby /opt/openstudio/bin/openstudio_meta install_gems
#   >cd /opt/openstudio/spec/
#   >gem install rspec
#   >rspec openstudio_algo_spec.rb
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
    expect(a.size).to eq(131)

    sleep(1)
    puts 'test download CSV results'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/download_data.csv?export=true"
    expect(a.size).to be >(5400)
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
    expect(a.size).to be >(3500)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("application/rdata; header=present")
    expect(a.headers[:content_disposition]).to include("SEB_calibration_NSGA_2013_metadata.RData")

    sleep(1)
    puts 'test download RData results'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/download_data.rdata?export=true"
    expect(a).not_to be_empty
    expect(a.size).to be >(2000)
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
    expect(a.size).to be >(4000)
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
    expect(a.size).to be >(4000)
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
    expect(a.size).to be >(1800)
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.headers[:content_type]).to eq("application/rdata; header=present")
    expect(a.headers[:content_disposition]).to include("SEB_calibration_NSGA_2013_results.RData")

    sleep(1)
    puts 'download selected pareto plot datapoints in RDATA'
    a = RestClient.get "http://#{@host}/analyses/86a529c9-8429-41e8-bca5-52b2628c8ff9/download_selected_datapoints.rdata?dps=0c0f61a0-58d7-43ab-a757-de491e272c38%2C511a2d68-555f-40be-8f4c-8559a98f51fc"
    expect(a).not_to be_empty
    expect(a.size).to be >(1800)
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
