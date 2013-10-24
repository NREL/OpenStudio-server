namespace :vagrant do
  desc 'setup the compute nodes in the database'
  task :setup => :environment do
    ComputeNode.delete_all

    node = ComputeNode.find_or_create_by(node_type: 'master', ip_address: '192.168.33.10')
    node.save!
    node = ComputeNode.find_or_create_by(node_type: 'worker', ip_address: '192.168.33.11')
    node.cores = 4
    node.save!
  end
end
