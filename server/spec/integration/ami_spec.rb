#*******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
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
#*******************************************************************************

require 'spec_helper'

require 'faraday'
require 'openstudio-analysis'
require 'openstudio-aws'

describe 'AmiIntegration' do
  context 'most recent AMIs from Jenkins' do
    before(:all) do
      # TODO: should check if the jenkins server AMI list is available (i.e. inside nrel's firewall),
      # else
      aws_options = {
        ami_lookup_version: 2,
        host: 'cbr-jenkins.nrel.gov',
        url: '/job/OpenStudio%20AMI%20List/lastSuccessfulBuild/artifact/vagrant'
      }
      @aws = OpenStudio::Aws::Aws.new(aws_options)
    end

    it 'should have the most recent AMIs' do
      puts @aws.default_amis
      expect(@aws.default_amis).not_to be_nil
    end

    it 'should create a cluster and submit a job' do
      # use the default instance type
      server_options = { instance_type: 'm1.large' }

      @aws.create_server(server_options)
      expect(@aws.os_aws.server).not_to be_nil

      worker_options = { instance_type: 'm1.large' }

      @aws.create_workers(1, worker_options)

      expect(@aws.os_aws.workers).to have(1).thing
      expect(@aws.os_aws.workers[0].data[:dns]).not_to be_nil

      # use faraday to do the test here
      f = Faraday.new(url: "http://#{@aws.os_aws.server.data[:dns]}") do |faraday|
        faraday.request :url_encoded # form-encode POST params
        faraday.response :logger
        faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
      end

      res = f.get('/')
      expect(res.status).to eq(200)
      expect(res.body).to include 'OpenStudio Cloud Management Console'

      puts Dir.pwd
      # test_file = File.expand_path("../testing/run_tests.rb")
      test_file = File.expand_path('../testing/run_example_lhs.rb')
      puts test_file
      if File.exist?(test_file)
        call_cmd = "cd ../testing && bundle update && bundle exec ruby #{test_file} 'http://#{@aws.os_aws.server.data[:dns]}'"
        puts "Calling: #{call_cmd}"

        res = system(call_cmd)

        exitcode = $CHILD_STATUS.exitstatus
        expect(exitcode).to eq(0)

      end
      puts res

      # TODO: same test but use the Analysis Gem
    end

    it 'should be able to ping the server' do
    end

    it 'should be able to load the server/worker from file' do
    end
  end

  context 'fixed AMI versions' do
    before(:all) do
      aws_options = { ami_lookup_version: 2, openstudio_server_version: '1.3.1' }
      @aws = OpenStudio::Aws::Aws.new(aws_options)
    end

    it 'should have fixed AMIs' do
      expect(@aws.default_amis[:cc2worker]).to eq('ami-4bbb8722')
      expect(@aws.default_amis[:server]).to eq('ami-a9bb87c0')
      expect(@aws.default_amis[:worker]).to eq('ami-39bb8750')
    end
  end
end
