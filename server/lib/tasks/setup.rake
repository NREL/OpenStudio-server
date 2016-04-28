namespace :setup do
  desc 'setup the default compute nodes in the database'
  task development: :environment do
    ComputeNode.delete_all

    ComputeNode.create!(node_type: 'server',  hostname: 'localhost', ip_address: '127.0.0.1', enabled: true, cores: 1)
    ComputeNode.create!(node_type: 'mongodb', hostname: 'localhost', ip_address: '127.0.0.1', enabled: true, cores: 2)

    # ComputeNode.create!(node_type: 'server',  hostname: 'os-server', ip_address: '192.168.33.10', enabled: true, cores: 1)
    # ComputeNode.create!(node_type: 'worker', hostname: 'os-worker', ip_address: '192.168.33.11', enabled: true, cores: 4)

    puts "Created new nodes for local run"
    ComputeNode.each do |cn|
      puts "  #{cn.inspect}"
    end
  end

  task docker: :environment do
    ComputeNode.delete_all

    ComputeNode.create!(node_type: 'server',  hostname: 'localhost', ip_address: '127.0.0.1', enabled: true, cores: 1)
    ComputeNode.create!(node_type: 'mongodb', hostname: 'localhost', ip_address: '127.0.0.1', enabled: true, cores: 2)

    puts "Created new nodes for docker run"
    ComputeNode.each do |cn|
      puts "  #{cn.inspect}"
    end
  end
end
