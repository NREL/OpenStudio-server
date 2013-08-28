require './remoteR.rb'

include RInterface

a = Rtest.new

command = "whoami"
a.send_command(command)

command = "pwd"
a.send_command(command)

command = "ls"
a.send_command(command)

command = "ruby /data/prototype/R/R_config.rb"
a.send_command(command)