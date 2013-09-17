namespace :vagrant do
  desc 'setup the compute nodes in the database'
  task :setup => :environment do
    MasterNode.delete_all
    WorkerNode.delete_all

    sn = MasterNode.find_or_create_by(:ip_address => '192.168.33.10')
    sn.save!

    wn = WorkerNode.find_or_create_by(:ip_address => '192.168.33.11') # todo read this from a file (somewhere) to set the worker nodes
    wn.save!
  end
end
