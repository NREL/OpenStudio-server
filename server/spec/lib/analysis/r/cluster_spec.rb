require 'spec_helper'

# not sure why i have to include this here
require 'rserve/simpler'

describe Analysis::R::Cluster do
  before :all do
    ComputeNode.delete_all
    FactoryGirl.create(:compute_node)

    # get an analysis (which should be loaded from factory girl)
    @analysis = Analysis.first
    @analysis.run_flag = true
    @analysis.save!

    #create an instance for R
    @r = Rserve::Simpler.new
  end

  context "create local cluster" do
    it "should create an R session" do
      @r.should_not be_nil
    end
    
    it "should configure the cluster with an analysis run_flagr" do
      @analysis.id.should_not be_nil
      
      cluster_class = Analysis::R::Cluster.new(@r, @analysis.id)
      cluster_class.should_not be_nil
      
      #get the master cluster IP address
      master_ip = ComputeNode.where(node_type: 'server').first.ip_address
      master_ip.should eq("192.168.33.10")
      
      cf = cluster_class.configure(master_ip)
      cf.should eq(true)
#      if !cluster.configure(master_ip)
#        raise "could not configure R cluster"
    end
    
    it "should start snow cluster" do
      cluster_class = Analysis::R::Cluster.new(@r, @analysis.id)
      cluster_class.should_not be_nil

      #get the master cluster IP address
      master_ip = ComputeNode.where(node_type: 'server').first.ip_address
      master_ip.should eq("192.168.33.10")
      
      ip_addresses = ComputeNode.worker_ips
      ip_addresses[:worker_ips].size.should eq(2)

      cf = cluster_class.start(ip_addresses)
      cf.should eq(true)

      cf = cluster_class.stop
      cf.should eq(true)
      
    end
    
  end
end

