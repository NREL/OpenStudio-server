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
local_path = File.dirname(__FILE__) + "/../pat/SimulateDataPoint.rb"
remote_path = "/home/vagrant/SimulateDataPoint.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path) # change back to .11

command = "chmod 774 /home/vagrant/SimulateDataPoint.rb"
a.send_command("192.168.33.10",command) # change back to .11

puts "make sure Rserve is running on server"
puts "R CMD Rserve --no-save --no-gui\n"

# Upload Analysis Zip File
local_path = File.dirname(__FILE__) + "/../pat/analysis.zip"
remote_path = "/home/vagrant/analysis.zip"
a.upload_file("192.168.33.10", local_path, remote_path) # change back to .11

command = "chmod 774 /home/vagrant/analysis.zip"
a.send_command("192.168.33.10",command) # change back to .11

# Unzip Analysis Zip File
command = "unzip /home/vagrant/analysis.zip -d /home/vagrant/"
a.send_command("192.168.33.10",command) # change back to .11

# command = "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /data/prototype/R/SDP_test.rb"
# a.shell_command("192.168.33.10",command)