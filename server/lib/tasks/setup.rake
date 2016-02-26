namespace :setup do
  desc 'setup the default compute nodes in the database'
  task development: :environment do
    ComputeNode.delete_all

    ComputeNode.create!(node_type: 'server',  hostname: 'localhost', ip_address: '127.0.0.1', valid: true, cores: 1)
    ComputeNode.create!(node_type: 'mongodb', hostname: 'localhost', ip_address: '127.0.0.1', valid: true, cores: 2)

    # ComputeNode.create!(node_type: 'server',  hostname: 'os-server', ip_address: '192.168.33.10', valid: true, cores: 1)
    # ComputeNode.create!(node_type: 'worker', hostname: 'os-worker', ip_address: '192.168.33.11', valid: true, cores: 4)
  end

  task docker: :environment do
    ComputeNode.delete_all

    ComputeNode.create!(node_type: 'server',  hostname: 'localhost', ip_address: '127.0.0.1', valid: true, cores: 1)
    ComputeNode.create!(node_type: 'mongodb', hostname: 'localhost', ip_address: '127.0.0.1', valid: true, cores: 2)
  end
end
