if @awake
  json.status do
    json.awake @awake.awake
    json.awake_delta @awake_delta
  end
else
  json.status
end

json.analyses do
  json.count Analysis.count
  json.na Analysis.all.only(:id).count { |a| a.status == 'na' }
  json.init Analysis.all.only(:id).count { |a| a.status == 'init' }
  json.queued Analysis.all.only(:id).count { |a| a.status == 'queued' }
  json.started Analysis.all.only(:id).count { |a| a.status == 'started' }
  json.completed Analysis.all.only(:id).count { |a| a.status == 'completed' }
end

json.data_points do
  json.count DataPoint.count
  json.na DataPoint.where(status: :na).count
  json.queued DataPoint.where(status: :queued).count
  json.started DataPoint.where(status: :started).count
  json.completed DataPoint.where(status: :completed).count
end

if @server.nil?
  json.server
else
  json.server @server, :id, :node_type, :ip_address, :hostname, :local_hostname, :user, :cores, :ami_id, :instance_id, :enabled
end

if @workers.empty?
  json.workers
else
  json.workers @workers, :id, :node_type, :ip_address, :hostname, :local_hostname, :user, :cores, :ami_id, :instance_id, :enabled
end

if @file_systems.nil?
  json.file_systems
else
  json.file_systems @file_systems, :mount_point, :percent_used, :mb_free, :mb_used, :mb_total
end
