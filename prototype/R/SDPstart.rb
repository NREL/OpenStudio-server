require './remoteR.rb'

include RInterface

a = Rtest.new

command = "whoami"
a.send_command("192.168.33.10",command)

command = "pwd"
a.send_command("192.168.33.10",command)

#command = "/usr/local/rbenv/shims/gem list"
#a.shell_command("192.168.33.10",command)

# Upload SimulateDataPoint
command = "rm /home/vagrant/SimulateDataPoint.rb"
a.send_command("192.168.33.11",command)
local_path = File.dirname(__FILE__) + "/../pat/SimulateDataPoint.rb"
remote_path = "/home/vagrant/SimulateDataPoint.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)

command = "chmod 774 /home/vagrant/SimulateDataPoint.rb"
a.send_command("192.168.33.11",command)

puts "make sure Rserve is running on server"
puts "R CMD Rserve --no-save --no-gui\n"

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
command = "unzip -o /home/vagrant/analysis.zip -d /home/vagrant/"
a.send_command("192.168.33.11",command)

##################################
# create mongoid dir
command = "rm -rf /home/vagrant/mongoid"
a.send_command("192.168.33.11",command)
command = "mkdir /home/vagrant/mongoid"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/algorithm.rb"
remote_path = "/home/vagrant/mongoid/algorithm.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/algorithm.rb"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/analysis.rb"
remote_path = "/home/vagrant/mongoid/analysis.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/analysis.rb"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/data_point.rb"
remote_path = "/home/vagrant/mongoid/data_point.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/data_point.rb"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/delayed_job_view.rb"
remote_path = "/home/vagrant/mongoid/delayed_job_view.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/delayed_job_view.rb"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/measure.rb"
remote_path = "/home/vagrant/mongoid/measure.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/measure.rb"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/problem.rb"
remote_path = "/home/vagrant/mongoid/problem.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/problem.rb"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/project.rb"
remote_path = "/home/vagrant/mongoid/project.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/project.rb"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/seed.rb"
remote_path = "/home/vagrant/mongoid/seed.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/seed.rb"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/variable.rb"
remote_path = "/home/vagrant/mongoid/variable.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/variable.rb"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/workflow_step.rb"
remote_path = "/home/vagrant/mongoid/workflow_step.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/workflow_step.rb"
a.send_command("192.168.33.11",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/config/initializers/inflections.rb"
remote_path = "/home/vagrant/mongoid/inflections.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/inflections.rb"
a.send_command("192.168.33.11",command)

# Upload mongoid/*
local_path = File.dirname(__FILE__) + "/../pat/mongoid.yml"
remote_path = "/home/vagrant/mongoid/mongoid.yml"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/mongoid.yml"
a.send_command("192.168.33.11",command)

####################################
# create mongoid dir
command = "rm -rf /home/vagrant/mongoid"
a.send_command("192.168.33.10",command)
command = "mkdir /home/vagrant/mongoid"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/algorithm.rb"
remote_path = "/home/vagrant/mongoid/algorithm.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/algorithm.rb"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/analysis.rb"
remote_path = "/home/vagrant/mongoid/analysis.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/analysis.rb"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/data_point.rb"
remote_path = "/home/vagrant/mongoid/data_point.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/data_point.rb"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/delayed_job_view.rb"
remote_path = "/home/vagrant/mongoid/delayed_job_view.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/delayed_job_view.rb"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/measure.rb"
remote_path = "/home/vagrant/mongoid/measure.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/measure.rb"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/problem.rb"
remote_path = "/home/vagrant/mongoid/problem.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/problem.rb"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/project.rb"
remote_path = "/home/vagrant/mongoid/project.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/project.rb"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/seed.rb"
remote_path = "/home/vagrant/mongoid/seed.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/seed.rb"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/variable.rb"
remote_path = "/home/vagrant/mongoid/variable.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/variable.rb"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/app/models/workflow_step.rb"
remote_path = "/home/vagrant/mongoid/workflow_step.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/workflow_step.rb"
a.send_command("192.168.33.10",command)

# Upload models/*
local_path = File.dirname(__FILE__) + "/../../openstudio-server/config/initializers/inflections.rb"
remote_path = "/home/vagrant/mongoid/inflections.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/inflections.rb"
a.send_command("192.168.33.10",command)

# Upload mongoid/*
local_path = File.dirname(__FILE__) + "/../pat/mongoid.yml"
remote_path = "/home/vagrant/mongoid/mongoid.yml"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/mongoid/mongoid.yml"
a.send_command("192.168.33.10",command)

####################################

# Upload config file for passwordless ssh/*
local_path = File.dirname(__FILE__) + "/../pat/config"
remote_path = "/home/vagrant/.ssh/config"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)
command = "chmod 774 /home/vagrant/.ssh/config"
a.send_command("192.168.33.11",command)

# Upload remoteR file for downloading results/*
local_path = File.dirname(__FILE__) + "/remoteR.rb"
remote_path = "/home/vagrant/remoteR.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/remoteR.rb"
a.send_command("192.168.33.10",command)

# Upload remoteR file for downloading results/*
local_path = File.dirname(__FILE__) + "/downloadR.rb"
remote_path = "/home/vagrant/downloadR.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/downloadR.rb"
a.send_command("192.168.33.10",command)


command = "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /data/prototype/R/SDP_test.rb"
a.shell_command("192.168.33.10",command)

command = "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /home/vagrant/downloadR.rb"
a.shell_command("192.168.33.10",command)