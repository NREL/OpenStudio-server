namespace :vagrant do
  desc 'setup the compute nodes in the database'
  task :setup => :environment do
    MasterNode.delete_all
    WorkerNode.delete_all

    sn = MasterNode.find_or_create_by(:ip_address => '192.168.33.10')
    sn.save!

    # todo read this from a file (somewhere) to set the worker nodes as there may be more than 1 file
    wn = WorkerNode.find_or_create_by(:ip_address => '192.168.33.11')
    wn.cores = 4
    wn.save!
  end
end
