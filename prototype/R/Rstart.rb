require './remoteR.rb'

include RInterface

a = Rtest.new

command = "whoami"
a.send_command(command)

command = "pwd"
a.send_command(command)

command = "/usr/local/rbenv/shims/gem list"
a.shell_command(command)

command = "/usr/local/rbenv/shims/ruby /data/prototype/R/R_config.rb"
a.shell_command(command)