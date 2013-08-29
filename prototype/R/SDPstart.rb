require './remoteR.rb'

include RInterface

a = Rtest.new

command = "whoami"
a.send_command("192.168.33.10",command)

command = "pwd"
a.send_command("192.168.33.10",command)

#command = "/usr/local/rbenv/shims/gem list"
#a.shell_command("192.168.33.10",command)

# Send Slave IPs to Master
local_path = "./SDP.rb"
remote_path = "/home/vagrant/SDP.rb"
# Upload File to slave Instance
a.upload_file("192.168.33.11", local_path, remote_path)

command = "chmod 774 /home/vagrant/SDP.rb"
a.send_command("192.168.33.11",command)

puts "make sure Rserve is running on server"
puts "R CMD Rserve --no-save --no-gui\n"

command = "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /data/prototype/R/SDP_test.rb"
a.shell_command("192.168.33.10",command)