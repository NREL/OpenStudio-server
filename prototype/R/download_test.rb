require './remoteR.rb'

include RInterface

a = Rtest.new



# Upload remoteR file for downloading results/*
local_path = File.dirname(__FILE__) + "/downloadR.rb"
remote_path = "/home/vagrant/downloadR.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.10", local_path, remote_path)
command = "chmod 774 /home/vagrant/downloadR.rb"
a.send_command("192.168.33.10",command)

# create analysis dir on server
command = "rm -rf /home/vagrant/analysis"
a.send_command("192.168.33.10",command)
command = "mkdir /home/vagrant/analysis"
a.send_command("192.168.33.10",command)


command = "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /home/vagrant/downloadR.rb"
a.shell_command("192.168.33.10",command)