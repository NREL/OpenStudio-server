class WorkerNode
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ip_address, :type => String
  field :hostname, :type => String
  field :user, :type => String
  field :password, :type => String
  field :cores, :type => Integer


  # Return all the worker IP addresses as a hash in prep for writing to a dataframe
  def self.to_hash
    worker_ips_hash = {}
    worker_ips_hash[:worker_ips] = []

    WorkerNode.all.each do |wn|
      (1..wn.cores).each { |i| worker_ips_hash[:worker_ips] << wn.ip_address }
    end
    Rails.logger.info("worker ip hash: #{worker_ips_hash}")

    worker_ips_hash
  end
end
