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
command = "rm /home/vagrant/uuid.rb"
a.send_command("192.168.33.11",command) # change back to .11
local_path = File.dirname(__FILE__) + "/uuid.rb"
remote_path = "/home/vagrant/uuid.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path) # change back to .11

command = "chmod 774 /home/vagrant/uuid.rb"
a.send_command("192.168.33.11",command) # change back to .11

# Remove Previous Analysis Data
#command = "rm -rf /home/vagrant/analysis"
#a.send_command("192.168.33.11",command) # change back to .11

# Unzip Analysis Zip File
#command = "unzip /home/vagrant/analysis.zip -d /home/vagrant/"
#a.send_command("192.168.33.11",command) # change back to .11

command = "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /data/prototype/R/Mongo_test.rb"
 a.shell_command("192.168.33.10",command)