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
#   >cd /opt/openstudio/server/spec/
#   >gem install rest-client rails_helper json rspec rspec-retry
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
  end

  it 'run nginx_tests', :nginx_tests do

    sleep(1)
    puts 'access main GUI page'
    a = RestClient.get "http://#{@host}"
    expect(a.headers[:status]).to eq("200 OK")
    expect(a.body).not_to include "Error"
    expect(a.body).to include "OpenStudio Cloud Management Console"
    
    sleep(1)
    puts 'check nginx status'
    a = RestClient.get "http://#{@host}/nginx"
    puts 'expect code 200'
    expect(a.code).to eq(200)
    puts 'expect \'Active connections\' in body'
    compare = a.body.include?('Active connections')
    expect(compare).to be true
    
    puts 'expect user to be \'root\''
    whoami = `whoami`
    puts "whoami: #{whoami}"
    expect(whoami).to eq("root\n")
    
    puts 'test nginx.conf file as user nginx'
    test_config = `su nginx -c 'sudo /opt/nginx/sbin/nginx -t 2>&1'`
    puts "test_config: #{test_config}"
    syntax = test_config.include?('syntax is ok')
    puts 'expect test_config to include \'syntax is ok\''
    expect(syntax).to be true
    successful = test_config.include?('test is successful')
    puts 'expect test_config to include \'test is successful\''
    expect(successful).to be true
    
    sleep(1)
    puts 'get nginx processes'
    nginx_pids = `ps aux|grep nginx`
    expect(nginx_pids).not_to be_empty
    puts 'get nginx PIDs'
    nginx_worker_pids = nginx_pids.split("\n").select{ |s| s =~ /nginx: worker process$/}.map {|e| e[%r{nginx \s*\d+\s}][%r{\d+}]} if !nginx_pids.nil?
    puts "nginx_worker_pids: #{nginx_worker_pids}"
    expect(nginx_worker_pids).not_to be_empty
    
    sleep(1)
    puts 'reload \'nginx.conf\' as user \'nginx\'' 
    `su nginx -c 'sudo /opt/nginx/sbin/nginx -s reload'`
    puts 'wait for 3 seconds'
    sleep(3)
    
    puts 'get nginx processes'
    nginx_pids = `ps aux|grep nginx`
    expect(nginx_pids).not_to be_empty
    puts 'get nginx PIDs'
    nginx_worker_pids2 = nginx_pids.split("\n").select{ |s| s =~ /nginx: worker process$/}.map {|e| e[%r{nginx \s*\d+\s}][%r{\d+}]} if !nginx_pids.nil?
    puts "nginx_worker_pids2: #{nginx_worker_pids2}"
    expect(nginx_worker_pids2).not_to be_empty
    expect(nginx_worker_pids2.is_a?(Array)).to be true
    new_pids = nginx_worker_pids2.is_a?(Array) && !nginx_worker_pids2.any? {|pids| nginx_worker_pids.include?(pids)}
    expect(new_pids).to be true
    
    sleep(1)
    puts 'check nginx status'
    a = RestClient.get "http://#{@host}/nginx"
    puts 'expect code 200'
    expect(a.code).to eq(200)
    puts 'expect \'Active connections\' in body'
    compare = a.body.include?('Active connections')
    expect(compare).to be true
  end    
end
