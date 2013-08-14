# runClass.rb 
# This ruby script shows how to use the classAWS.rb class
# to launch Master and Slaves EC2 instances. 

require './classAWS'

include AwsInterface

# Create Instance of AwsAdapter
a = AwsAdapter.new

# Launch Master 
# The file  "master_script.txt" will be passed to the 
# instance as user-data. This file contains bash commands
# to send set up the /etc/hosts and /etc/hostname files.
master_info = a.launch_master("master_script.sh")
master_instance = Array.new(0)
master_instance.push(master_info.instance)

# Prepare SLAVE SCRIPT
# The file  "slave_script.txt" will be passed to the 
# instance as user-data. This file contains bash commands
# to send set up the /etc/hosts and /etc/hostname files.
master_ip = master_info.ip_address
master_dns = master_info.dns_name 
master_hostname = "master_hostname"
prepare_slave_script("slave_script.sh", master_ip, master_dns, master_hostname)
#prepare_slave_script("master_script.sh", master_ip, master_dns, master_hostname)

# Launch Slaves 
slave_info = a.launch_slave(2, master_info, "slave_script.sh")
slave_instances = Array.new(0)
slave_info.each {|struct| slave_instances.push(struct.instance)}

# Get IPs
isMaster = 1
ip_add = a.get_ip(isMaster)
ip_add.each{|ip| puts "IP: #{ip}"}
isMaster = 0
ip_add = a.get_ip(isMaster)
ip_add.each{|ip| puts "IP: #{ip}"}

# Get DNS
isMaster = 1
dns_name = a.get_dns(isMaster)
dns_name.each{|dns| puts "DNS: #{dns}"}
isMaster = 0
dns_name = a.get_dns(isMaster)
dns_name.each{|dns| puts "DNS: #{dns}"}

# Send Slave IPs to Master
local_path = "./slave_info.sh"
remote_path = "/home/ubuntu/hosts_slave_file.sh"
text = ""
slave_info.each {|info| text << "#{info.ip_address}\n"}
File.open(local_path, 'w+') {|f| f.write(text) }
# Upload File to Master Instance
a.upload_file(master_instance[0], local_path, remote_path)

# slaves and masters are known

# TODO: need to upload the IP ADDRESSES as a file (called "ip_addresses") such as 
#    192.168.33.10|ubuntu|ubuntu
#
text = ""
#master_info.each {|info| text << "#{info.ip_address}|ubuntu|ubuntu\n"}
#text << "#{master_info.ip_address}|ubuntu|ubuntu\n"
#slave_info.each {|info| text << "#{info.ip_address}|ubuntu|ubuntu\n"}
#File.open("ip_addresses", 'w+') {|f| f.write(text) }
text << "#{master_info.dns_name}|ubuntu|ubuntu\n"
slave_info.each {|info| text << "#{info.dns_name}|ubuntu|ubuntu\n"}
File.open("ip_addresses", 'w+') {|f| f.write(text) }

# Right now these paths are assuming that we are in the same directory as the files
upload_files = ["ip_addresses", "setup-ssh-keys.sh", "setup-ssh-worker-nodes.sh", "setup-ssh-worker-nodes.expect", "start_rserve.sh"]
upload_files.each do |file|
  a.upload_file(master_instance[0], "./#{file}", "./#{File.basename(file)}")
end

# Send Commands
command = "chmod 774 ~/setup-ssh-keys.sh"
master_instance.each { |instance|
  a.send_command(instance, command)
}

command = "~/setup-ssh-keys.sh"
master_instance.each { |instance|
  a.send_command(instance, command)
}

command = "chmod 774 ~/setup-ssh-worker-nodes.expect"
master_instance.each { |instance|
  a.send_command(instance, command)
}
 
command = "chmod 774 ~/setup-ssh-worker-nodes.sh"
master_instance.each { |instance|
  a.send_command(instance, command)
}

command = "~/setup-ssh-worker-nodes.sh"
master_instance.each { |instance|
  a.send_command(instance, command)
}
 
command = "chmod 774 ~/start_rserve.sh"
master_instance.each { |instance|
  a.send_command(instance, command)
}

command = "nohup ~/start_rserve.sh </dev/null >/dev/null 2>&1 &"
master_instance.each { |instance|
  a.send_command(instance, command)
}
 
 # test, ssh into the master, then ssh into a worker node.  you should 
 # not be asked to authenticate a key nor enter username/password


# Send Command ls
#command = "ls /home/ubuntu/"
#master_instance.each { |instance|
#  a.send_command(instance, command)
#}

# Send Command
#command = "cat /etc/hosts"
#slave_instances.each { |instance|
#  a.send_command(instance, command)
#}

# Send Command
#command = "cat /etc/hostname"
#slave_instances.each { |instance|
#  a.send_command(instance, command)
#}

# Terminate Instance
#a.terminate_master()
#a.terminate_slaves()

# Delete key pair and group
#a.clean_up()


