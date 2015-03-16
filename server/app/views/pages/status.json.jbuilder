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
  json.na Analysis.all.only(:id).select{ |a| a.status == 'na'}.count
  json.init Analysis.all.only(:id).select{ |a| a.status == 'init'}.count
  json.queued Analysis.all.only(:id).select{ |a| a.status == 'queued'}.count
  json.started Analysis.all.only(:id).select{ |a| a.status == 'started'}.count
  json.completed Analysis.all.only(:id).select{ |a| a.status == 'completed'}.count
end


json.data_points do
  json.count DataPoint.count
  json.na DataPoint.where(download_status: :na).count
  json.queued DataPoint.where(download_status: :queued).count
  json.started DataPoint.where(download_status: :started).count
  json.completed DataPoint.where(download_status: :completed).count
end

if @mnt_fs
  json.data_file_system do
    json.mount_point @mnt_fs.first[:mount_point]
    json.percent_used @mnt_fs.first[:percent_used]
    json.mb_free @mnt_fs.first[:mb_free]
    json.mb_used @mnt_fs.first[:mb_used]
    json.mb_total @mnt_fs.first[:mb_total]
  end
else
  json.data_file_system
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


if @file_systems.nil?
  json.file_systems
else
  json.file_systems @file_systems, :mount_point, :percent_used, :mb_free, :mb_used, :mb_total
end