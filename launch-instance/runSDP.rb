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
master_hostname = "master_name"
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
#
text = ""
#master_info.each {|info| text << "#{info.ip_address}|ubuntu|ubuntu\n"}
#text << "#{master_info.ip_address}|ubuntu|ubuntu\n"
#slave_info.each {|info| text << "#{info.ip_address}|ubuntu|ubuntu\n"}
#File.open("ip_addresses", 'w+') {|f| f.write(text) }
text << "#{master_info.dns_name}|ubuntu|ubuntu\n"
slave_info.each {|info| text << "#{info.dns_name}|ubuntu|ubuntu\n"}
File.open("ip_addresses", 'w+') {|f| f.write(text) }

text = ""
text << "#{master_info.dns_name}"
File.open("master_ip_address", 'w+') {|f| f.write(text) }

# Right now these paths are assuming that we are in the same directory as the files
upload_files = ["ip_addresses", "setup-ssh-keys.sh", "setup-ssh-worker-nodes.sh", "setup-ssh-worker-nodes.expect", "start_rserve.sh"]
upload_files.each do |file|
  a.upload_file(master_instance[0], "./#{file}", "./#{File.basename(file)}")
end

##################################
# Setup SSH and Rserve Commands
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
 
#end of setup 
################### 
 
############################################ 
# Upload SimulateDataPoint
slave_instances.each { |instance|
  command = "rm /home/ubuntu/SimulateDataPoint.rb"
  a.send_command(instance,command)
}  
local_path = File.dirname(__FILE__) + "/../prototype/pat/SimulateDataPoint_ec2.rb"
remote_path = "/home/ubuntu/SimulateDataPoint.rb"
# Upload File to slave Instance
slave_instances.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}
slave_instances.each { |instance|
  command = "chmod 774 /home/ubuntu/SimulateDataPoint.rb"
  a.send_command(instance,command)
}
#################################################
# Upload analysis.zip
slave_instances.each { |instance|
  command = "rm /home/ubuntu/analysis.zip"
  a.send_command(instance,command)
}  
local_path = File.dirname(__FILE__) + "/../prototype/pat/analysis.zip"
remote_path = "/home/ubuntu/analysis.zip"
# Upload File to slave Instance
slave_instances.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}
slave_instances.each { |instance|
  command = "chmod 774 /home/ubuntu/analysis.zip"
  a.send_command(instance,command)
}
# Remove Previous Analysis Data
slave_instances.each { |instance|
  command = "rm -rf /home/ubuntu/analysis"
  a.send_command(instance,command)
}  
# Unzip Analysis Zip File
slave_instances.each { |instance|
  command = "unzip -o /home/ubuntu/analysis.zip -d /home/ubuntu/"
  a.send_command(instance,command)
}  
# delete Analysis Zip File
slave_instances.each { |instance|
  command = "rm /home/ubuntu/analysis.zip"
  a.send_command(instance,command)
}  

###########################
# create models dir
command = "rm -rf /home/ubuntu/models.zip"
slave_instances.each { |instance|
  a.send_command(instance,command)
}  
master_instance.each { |instance|
  a.send_command(instance,command)
}  

local_path = File.dirname(__FILE__) + "/../openstudio-server/app/models.zip"
remote_path = "/home/ubuntu/models.zip"
# Upload File to slave Instance
slave_instances.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}
master_instance.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}

command = "chmod 774 /home/ubuntu/models.zip"
slave_instances.each { |instance|
  a.send_command(instance,command)
}
master_instance.each { |instance|
  a.send_command(instance,command)
} 

# Remove Previous models Data
command = "rm -rf /home/ubuntu/models"
slave_instances.each { |instance|
  a.send_command(instance,command)
} 
master_instance.each { |instance|
  a.send_command(instance,command)
} 

# Unzip models Zip File
command = "unzip -o /home/ubuntu/models.zip -d /home/ubuntu/"
slave_instances.each { |instance|
  a.send_command(instance,command)
}  
master_instance.each { |instance|
  a.send_command(instance,command)
} 

# delete models Zip File
command = "rm /home/ubuntu/models.zip"
slave_instances.each { |instance|
  a.send_command(instance,command)
}  
master_instance.each { |instance|
  a.send_command(instance,command)
} 

###############################
# Upload inflections
local_path = File.dirname(__FILE__) + "/../openstudio-server/config/initializers/inflections.rb"
remote_path = "/home/ubuntu/models/inflections.rb"
# Upload File to slave Instance
slave_instances.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}
master_instance.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}

command = "chmod 774 /home/ubuntu/models/inflections.rb"
slave_instances.each { |instance|
  a.send_command(instance,command)
}
master_instance.each { |instance|
  a.send_command(instance,command)
}

###############################
# Upload mongoid
local_path = File.dirname(__FILE__) + "/../prototype/pat/mongoid.yml"
remote_path = "/home/ubuntu/models/mongoid.yml"
# Upload File to slave Instance
slave_instances.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}
master_instance.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}

command = "chmod 774 /home/ubuntu/models/mongoid.yml"
slave_instances.each { |instance|
  a.send_command(instance,command)
}
master_instance.each { |instance|
  a.send_command(instance,command)
}

###############################
# Upload remoteR
local_path = File.dirname(__FILE__) + "/remoteR.rb"
remote_path = "/home/ubuntu/remoteR.rb"
# Upload File to master Instance
master_instance.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}

command = "chmod 774 /home/ubuntu/remoteR.rb"
master_instance.each { |instance|
  a.send_command(instance,command)
}

###############################
# Upload downloadR.rb
local_path = File.dirname(__FILE__) + "/downloadR.rb"
remote_path = "/home/ubuntu/downloadR.rb"
# Upload File to master Instance
master_instance.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}

command = "chmod 774 /home/ubuntu/downloadR.rb"
master_instance.each { |instance|
  a.send_command(instance,command)
}

###############################
# Upload data_point_uuids
local_path = File.dirname(__FILE__) + "/data_point_uuids.txt"
remote_path = "/home/ubuntu/data_point_uuids.txt"
# Upload File to master Instance
master_instance.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}

command = "chmod 774 /home/ubuntu/data_point_uuids.txt"
master_instance.each { |instance|
  a.send_command(instance,command)
}

###############################
# Upload data_point_uuids
local_path = File.dirname(__FILE__) + "/master_ip_address"
remote_path = "/home/ubuntu/master_ip_address"
# Upload File to master Instance
master_instance.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}

command = "chmod 774 /home/ubuntu/master_ip_address"
master_instance.each { |instance|
  a.send_command(instance,command)
}

###############################
# Upload SDP_EC2.rb
local_path = File.dirname(__FILE__) + "/SDP_EC2.rb"
remote_path = "/home/ubuntu/SDP_EC2.rb"
# Upload File to master Instance
master_instance.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}

command = "chmod 774 /home/ubuntu/SDP_EC2.rb"
master_instance.each { |instance|
  a.send_command(instance,command)
}

####################
# run command
#command = "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /data/prototype/R/SDP_test.rb"
#master_instance.each { |instance|
#  a.shell_command(instance, command)
#}
####################
# download command
#command = "/usr/local/rbenv/shims/ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ /home/vagrant/downloadR.rb"
#master_instance.each { |instance|
#  a.shell_command(instance, command)
#}

# Terminate Instance
#a.terminate_master()
#a.terminate_slaves()

# Delete key pair and group
#a.clean_up()


