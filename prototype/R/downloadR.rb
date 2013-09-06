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
end



exit

# Upload Analysis Zip File
local_path = File.dirname(__FILE__) + "/../pat/analysis.zip"
remote_path = "/home/vagrant/analysis.zip"
a.upload_file("192.168.33.11", local_path, remote_path)

command = "chmod 774 /home/vagrant/analysis.zip"
a.send_command("192.168.33.11",command)

# Remove Previous Analysis Data
command = "rm -rf /home/vagrant/analysis"
a.send_command("192.168.33.11",command)

# Unzip Analysis Zip File
command = "unzip /home/vagrant/analysis.zip -d /home/vagrant/"
a.send_command("192.168.33.11",command)




