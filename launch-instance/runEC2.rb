# This ruby script shows how to use the classAWS.rb class to launch the Server and Worker nodes
# on EC2. After the servers are configures, the latter part of the script uses the API to
# run an example analysis.

require './classAWS'

include AwsInterface

DEBUG = FALSE

# Create Instance of AwsAdapter
a = AwsAdapter.new #("~/.ssh/amazontest.pub")

# Launch Master
# The file  "master_script.sh" will be passed to the
# instance as user-data. This file contains bash commands
# to send set up the /etc/hosts and /etc/hostname files.
# The file also has basic commands to create directory and
# copy files to the right places.
master_info = a.launch_master("master_script.sh")
master_instance = Array.new(0)
master_instance.push(master_info.instance)

# Prepare SLAVE SCRIPT
# The file  "slave_script.sh" will be passed to the
# instance as user-data. This file contains bash commands
# to send set up the /etc/hosts and /etc/hostname files.
master_ip = master_info.ip_address
master_dns = master_info.dns_name
master_hostname = "master"
puts "master ip: #{master_ip}"
prepare_slave_script("slave_script.sh", master_ip, master_dns, master_hostname)
prepare_mongoid_script(master_ip)

# Launch Slaves 
slave_info = a.launch_slave(2, master_info, "slave_script.sh")
slave_instances = Array.new(0)
slave_info.each { |struct| slave_instances.push(struct.instance) }

# Get IPs
isMaster = 1
ip_add = a.get_ip(isMaster)
ip_add.each { |ip| puts "IP: #{ip}" }
isMaster = 0
ip_add = a.get_ip(isMaster)
ip_add.each { |ip| puts "IP: #{ip}" }

# Get DNS
isMaster = 1
dns_name = a.get_dns(isMaster)
dns_name.each { |dns| puts "DNS: #{dns}" }
isMaster = 0
dns_name = a.get_dns(isMaster)
dns_name.each { |dns| puts "DNS: #{dns}" }

# create the ip address file for uploading to master and worker
# TODO: get the number of cores and replace in this script
File.open("ip_addresses", 'w+') do |f|
  f << "master|#{master_info.ip_address}|#{master_info.dns_name}|2|ubuntu|ubuntu\n"
  slave_info.each do |info|
    f << "worker|#{info.ip_address}|#{info.dns_name}|2|ubuntu|ubuntu\n"
  end
end

# list of files to upload to the user home directory
a.upload_file(master_instance[0], "./ip_addresses", "./ip_addresses")

# Upload mongoid
local_path = "./mongoid.yml"
remote_path = "/mnt/openstudio/rails-models/mongoid.yml"
# Upload File to master and slave instance
a.upload_file(master_instance[0], local_path, remote_path)
slave_instances.each { |instance|
  a.upload_file(instance, local_path, remote_path)
}

master_instance.each { |instance|
  a.send_command(instance, command)
}
slave_instances.each { |instance|
  a.send_command(instance, command)
}


# Setup SSH
#commands = []
#commands << "~/setup-ssh-keys.expect"
#commands << "~/setup-ssh-worker-nodes.sh ip_addresses"
#master_instance.each do |instance|
#  commands.each do |command|
#    a.send_command(instance, command)
#  end
#end


command = "chmod 664 /mnt/openstudio/rails-models/mongoid.yml"


if DEBUG
  # The code below to the end should only be used for debugging because most (if not all)
  # of the files below are already on the server.
  upload_files = ["setup-ssh-keys.expect", "setup-ssh-worker-nodes.sh", "setup-ssh-worker-nodes.expect"]
  upload_files.each do |file|
    a.upload_file(master_instance[0], "./#{file}", "~/#{File.basename(file)}")
  end

  # Upload SimulateDataPoint (this is already on the servers, just upload if you are in DEBUG mode)
  slave_instances.each { |instance|
    command = "rm /mnt/openstudio/SimulateDataPoint.rb"
    a.send_command(instance, command)
    command = "rm /mnt/openstudio/CommunicateResults_Mongo.rb"
    a.send_command(instance, command)
  }
  local_path = File.dirname(__FILE__) + "/../prototype/pat/SimulateDataPoint.rb"
  remote_path = "/mnt/openstudio/SimulateDataPoint.rb"

  # Upload File to slave Instance
  slave_instances.each { |instance|
    a.upload_file(instance, local_path, remote_path)
    command = "chmod 774 " + remote_path
    a.send_command(instance, command)
  }
  local_path = File.dirname(__FILE__) + "/../prototype/pat/CommunicateResults_Mongo.rb"
  remote_path = "/mnt/openstudio/CommunicateResults_Mongo.rb"
  slave_instances.each { |instance|
    a.upload_file(instance, local_path, remote_path)
    command = "chmod 774 " + remote_path
    a.send_command(instance, command)
  }

  # create rails-models dir  -- temp: this will be on the image by default
  commands = []
  commands << "rm -rf /mnt/openstudio/rails-models/"
  commands << "mkdir -p /mnt/openstudio/rails-models"
  commands.each do |command|
    slave_instances.each { |instance|
      a.send_command(instance, command)
    }
  end

  local_path = File.dirname(__FILE__) + "/../prototype/pat/rails-models.zip"
  remote_path = "/mnt/openstudio/rails-models/rails-models.zip"
  # Upload File to slave Instance
  slave_instances.each { |instance|
    a.upload_file(instance, local_path, remote_path)
  }

  commands = []
  commands << "chmod 775 /mnt/openstudio/rails-models"
  commands << "chmod 664 /mnt/openstudio/rails-models/rails-models.zip"
  commands << "unzip -o /mnt/openstudio/rails-models/rails-models.zip"
  commands << "rm /mnt/openstudio/rails-models/rails-models.zip"

  commands.each do |command|
    slave_instances.each { |instance|
      a.send_command(instance, command)
    }
  end
end

# Terminate Instance
#a.terminate_master()
#a.terminate_slaves()

# Delete key pair and group
#a.clean_up()


