if @awake.nil?
  json.status
else
  json.status @awake, :awake
end

if @mnt_fs.nil?
  json.data_file_system
else
  json.data_file_system @mnt_fs, :mount_point, :percent_used, :mb_free, :mb_used, :mb_total
end


if @file_systems.nil?
  json.file_systems
else
  json.file_systems @file_systems, :mount_point, :percent_used, :mb_free, :mb_used, :mb_total
end


if @server.nil?
  json.server
else
  json.server @server, :id, :node_type, :ip_address, :hostname, :local_hostname, :user, :cores, :ami_id, :instance_id, :valid
end

if @workers.empty?
  json.workers
else
  json.workers @workers, :id, :node_type, :ip_address, :hostname, :local_hostname, :user, :cores, :ami_id, :instance_id, :valid
end
