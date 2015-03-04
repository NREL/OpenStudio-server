if  @awake.nil?
	json.status 
else
	json.status @awake, :awake
end

if @server.nil?
  json.server
else
  json.server @server, :id, :node_type, :ip_address, :hostname, :local_hostname, :user, :password, :cores, :ami_id, :instance_id, :valid
end

if @workers.empty?
	json.workers
else
  json.workers @workers, :id, :node_type, :ip_address, :hostname, :local_hostname, :user, :password, :cores, :ami_id, :instance_id, :valid
end
