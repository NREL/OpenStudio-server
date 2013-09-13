require 'mongoid'
require 'mongoid_paperclip'
require '/usr/local/lib/rails-models/algorithm'
require '/usr/local/lib/rails-models/analysis'
require '/usr/local/lib/rails-models/data_point'
#require '/home/ubuntu/models/delayed_job_view'
require '/usr/local/lib/rails-models/measure'
require '/usr/local/lib/rails-models/problem'
require '/usr/local/lib/rails-models/project'
require '/usr/local/lib/rails-models/seed'
require '/usr/local/lib/rails-models/variable'
require '/usr/local/lib/rails-models/workflow_step'
require '/usr/local/lib/rails-models/inflections'

require 'mnt/openstudio/net_scp.rb'

include RInterface

a = Rtest.new

Mongoid.load!("/usr/local/lib/rails-models/mongoid.yml", :development)


file = File.open('/mnt/openstudio/data_point_uuids.txt','r')
lines = file.readlines
file.close
lines.each do |line|
  uuid = line[0...-1]
  dp = DataPoint.find_by(uuid: uuid)
  puts dp.ip_address
  puts dp.uuid
  puts dp.values
  adir = dp.analysis_id
  analysis_dir = "/mnt/openstudio/analysis_" << adir[1...-1]
  if Dir.exists?(analysis_dir) == false
    Dir.mkdir(analysis_dir)
  end  
  
  # zip datapoint File
  datapoint_path = "data_point_" << line[0...-1]
  datapoint_path_zip = "data_point_" << line[0...-1] << ".zip"
  command = "cd /mnt/openstudio/analysis ; zip -r " << datapoint_path_zip << " " << datapoint_path
  a.shell_command(dp.ip_address,command)
  
  # download datapoint
  #local_path = "/home/ubuntu/analysis/" << datapoint_path_zip 
  local_path = analysis_dir << "/" << datapoint_path_zip 
  remote_path = "/mnt/openstudio/analysis/" << datapoint_path_zip
  if File.exists?(local_path) == true
    `rm -rf #{local_path}`
  end
  # download File to slave Instance
  a.download_file(dp.ip_address, remote_path, local_path)
  command = "chmod 774 " << local_path
  `#{command}`
  
  # Unzip Analysis Zip File
  #command = "unzip " << "/home/ubuntu/analysis/" << datapoint_path_zip << " -d " << "/home/ubuntu/analysis/"
  command = "unzip -o " << local_path << " -d " << "/mnt/openstudio/analysis_" << adir[1...-1]
  `#{command}`
  
end
