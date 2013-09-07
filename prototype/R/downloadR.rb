require 'mongoid'
require 'mongoid_paperclip'
require '/home/vagrant/mongoid/algorithm'
require '/home/vagrant/mongoid/analysis'
require '/home/vagrant/mongoid/data_point'
#require '/home/vagrant/mongoid/delayed_job_view'
require '/home/vagrant/mongoid/measure'
require '/home/vagrant/mongoid/problem'
require '/home/vagrant/mongoid/project'
require '/home/vagrant/mongoid/seed'
require '/home/vagrant/mongoid/variable'
require '/home/vagrant/mongoid/workflow_step'
require '/home/vagrant/mongoid/inflections'

require './remoteR.rb'

include RInterface

a = Rtest.new

Mongoid.load!("/home/vagrant/mongoid/mongoid.yml", :development)


file = File.open('/data/prototype/R/data_point_uuids.txt','r')
lines = file.readlines
file.close
lines.each do |line|
  uuid = "{" << line[0...-1] << "}"
  dp = DataPoint.find_by(uuid: uuid)
  puts dp.ip_address
  puts dp.uuid
  puts dp.values
  
  # zip datapoint File
  datapoint_path = "data_point_" << line[0...-1]
  datapoint_path_zip = "data_point_" << line[0...-1] << ".zip"
  command = "cd /home/vagrant/analysis ; zip -r " << datapoint_path_zip << " " << datapoint_path
  a.shell_command("192.168.33.11",command)
  
  # download datapoint
  local_path = "/home/vagrant/analysis/" << datapoint_path_zip 
  remote_path = "/home/vagrant/analysis/" << datapoint_path_zip
  # download File to slave Instance
  a.download_file("192.168.33.11", remote_path, local_path)
  command = "chmod 774 " << local_path
  a.send_command("192.168.33.10",command)
  
  # Unzip Analysis Zip File
  command = "unzip " << "/home/vagrant/analysis/" << datapoint_path_zip << " -d " << datapoint_path
  a.send_command("192.168.33.10",command)
  
end
