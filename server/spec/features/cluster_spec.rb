# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

RSpec.describe AnalysisLibrary::R::Cluster, type: :feature do
  before :all do
    ComputeNode.destroy_all
    Project.destroy_all
    FactoryBot.create(:project_with_analyses).analyses
    FactoryBot.create(:compute_node)

    # get an analysis (which should be loaded from factory girl)
    @analysis = Analysis.first
    @analysis.run_flag = true
    @analysis.save!

    # create an instance for R
    @r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'], APP_CONFIG['rserve_port'])
  end

  context 'create local cluster' do
    it 'creates an R session', depends_r: true do
      expect(@r).not_to be_nil
    end

    it 'starts snow cluster', depends_r: true do
      cluster_class = AnalysisLibrary::R::Cluster.new(@r, @analysis.id)
      expect(cluster_class).not_to be_nil

      # get the master cluster IP address
      master_ip = ComputeNode.where(node_type: 'server').first.ip_address
      expect(master_ip).to eq('localhost')

      ip_addresses = ComputeNode.worker_ips
      expect(ip_addresses[:worker_ips].size).to eq 2

      cf = cluster_class.start(ip_addresses)
      expect(cf).to eq true

      cf = cluster_class.stop
      expect(cf).to eq true
    end
  end
end
