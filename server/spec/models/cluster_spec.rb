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

require 'rails_helper'

RSpec.describe AnalysisLibrary::R::Cluster, type: :feature do
  before :all do
    ComputeNode.destroy_all
    Project.destroy_all
    FactoryGirl.create(:project_with_analyses).analyses
    FactoryGirl.create(:compute_node)

    # get an analysis (which should be loaded from factory girl)
    @analysis = Analysis.first
    @analysis.run_flag = true
    @analysis.save!

    # create an instance for R
    @r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                 APP_CONFIG['rserve_port'])
  end

  context 'create local cluster' do
    it 'should create an R session' do
      @r.should_not be_nil
    end

    it 'should configure the cluster with an analysis run_flag', js: true do
      @analysis.id.should_not be_nil

      cluster_class = AnalysisLibrary::R::Cluster.new(@r, @analysis.id)
      cluster_class.should_not be_nil

      # get the master cluster IP address
      master_ip = ComputeNode.where(node_type: 'server').first.ip_address
      master_ip.should eq('localhost')

      APP_CONFIG['os_server_host_url'] = "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"

      cf = cluster_class.configure
      cf.should eq(true)
    end

    it 'should start snow cluster' do
      cluster_class = AnalysisLibrary::R::Cluster.new(@r, @analysis.id)
      cluster_class.should_not be_nil

      # get the master cluster IP address
      master_ip = ComputeNode.where(node_type: 'server').first.ip_address
      master_ip.should eq('localhost')

      ip_addresses = ComputeNode.worker_ips
      ip_addresses[:worker_ips].size.should eq(2)

      cf = cluster_class.start(ip_addresses)
      cf.should eq(true)

      cf = cluster_class.stop
      cf.should eq(true)
    end
  end
end
