require './remoteR.rb'

include RInterface

a = Rtest.new

command = "whoami"
a.send_command("192.168.33.10",command)

command = "pwd"
a.send_command("192.168.33.10",command)

command = "/usr/local/rbenv/shims/gem list"
a.shell_command("192.168.33.10",command)

command = "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /data/prototype/R/R_config.rb"
a.shell_command("192.168.33.10",command)