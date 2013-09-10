require File.expand_path(File.dirname(__FILE__) + '/samples_config')
require 'net/http'
require 'net/ssh'
require 'net/scp'

module AwsInterface 
  class AwsAdapter
    IMAGE_ID_SERVER = "ami-d3074eba"
    IMAGE_ID_WORKER = "ami-9d074ef4"
    REGION = "us-east-1"
    #IMAGE_ID = "ami-4c0d4925" #-Nicks
    MASTER_USER_DATA_FILE = "master_script.sh"
    SLAVE_USER_DATA_FILE = "slave_script.sh"
      
    CONFIG_FILE = '/samples_config'
    ACCESS_KEY_ID = ''
    SECRET_ACCESS_KEY = ''

#======================= initialization ======================#    
    def initialize()
      # Sets the AWS::EC2 client 
      # Creates Security Group
      # Creates Key Pair
      # Authorize Traffice
      puts 'Initializing'
      # Region
      puts "Region: #{REGION}"      
      # Image ID
      #puts "Image ID: #{IMAGE_ID}"
      # Set Security Credentials
      @ec2 = AWS::EC2.new(:region => REGION,
                          :ssl_verify_peer => false)                    
    
      # Create Security Group
      @group = @ec2.security_groups.create("sec-group-#{Time.now.to_i}")
      puts "Group: #{@group}"
      # web traffic
      @group.authorize_ingress(:tcp, 80)
      # allow ping
      @group.allow_ping()
      # ftp traffic
      @group.authorize_ingress(:tcp, 20..21)
      # ftp traffic
      @group.authorize_ingress(:tcp, 1..65535)
      # ssh access
      @group.authorize_ingress(:tcp, 22, '0.0.0.0/0')
      #@group.authorize_ingress(:tcp, 22, '0.0.0.0/0', '1.1.1.1/0', '2.2.2.2/0')
      # telnet
      @group.authorize_ingress(:tcp, 23, '0.0.0.0/0')
    
      # generate a key pair
      @key_pair = @ec2.key_pairs.create("key-pair-#{Time.now.to_i}")
      puts "Generated keypair #{@key_pair.name}, fingerprint: #{@key_pair.fingerprint}"
      # save key to file
      File.open("ec2.pem", "w") do |f| f.write(@key_pair.private_key) 
       end

      # instances array
      @instances_master = Array.new(0)
      @instances_slave = Array.new(0)
      @slave_info = Array.new(0)
    end

#======================= launch master ======================#    
    # Launch Master
    # Returns a struct with information about the Master Instance.
    # userdata_file is the file that will be sent to the instance 
    # as user-data. This contains the bash commands to execute at 
    # booting. 
    def launch_master(userdata_file)
      user_data = IO.read(userdata_file)
      puts "Launching Master..."
      #@instance = @image.run_instance(:key_pair => @key_pair,
      #                               :security_groups => @group,
      #                               :user_data => user_data,
      #                               :instance_type => "m1.medium")
      @instance = @ec2.instances.create(:image_id => IMAGE_ID_SERVER, 
                                        :key_pair => @key_pair, 
                                        :security_groups => @group,
                                        :user_data => user_data,
                                        :instance_type => "m1.medium")                                        
      
      @instances_master.push(@instance)
      
      # sleep until ready
      sleep 5 while @instance.status == :pending
      
      # display launched instances
      puts "Launched instance #{@instance.instance_id}, status: #{@instance.status}}"
      
      # check instance status
      exit 1 unless @instance.status == :running
      
      # display instance status
      puts "Instance: #{@instance.instance_id}, Status: #{@instance.status}"
      
      # Return Master Info (Struct) 
      return create_struct(@instance)
    end
    
#======================= launch slave ======================#
    # Launch Slave
    # Returns an array with the information (struct) about the Slave Instances.
    # userdata_file is the file that will be sent to the instance 
    # as user-data. This contains the bash commands to execute at 
    # booting.
    def launch_slave(num, master_info, userdata_file)
      # master_info
      # Process Master Info
      

      user_data = IO.read(userdata_file)
      # launch instances num = number of instances
      num.times do
        puts "Launching Slaves..."
       # @instance = @image.run_instance(:key_pair => @key_pair,
       #                                 :security_groups => @group,
       #                                 :user_data => user_data, 
       #                                 :instance_type => "m1.medium")
        @instance = @ec2.instances.create(:image_id => IMAGE_ID_WORKER, 
                                          :key_pair => @key_pair, 
                                          :security_groups => @group,
                                          :user_data => user_data,
                                          :instance_type => "t1.micro") 
                                          #:instance_type => "m1.medium") 
        @instances_slave.push(@instance)
      end
      # sleep until ready
      sleep 5 while @instances_slave.any? {|instance| instance.status == :pending}
      
      # Display Launched Instances
      @instances_slave.each { |instance| puts "Launched instance #{instance.instance_id}, status: #{instance.status}"}
      
      # Check Instance Status
      exit 1 unless @instances_slave.all? {|instance| instance.status == :running}
      
      # Display Instance Status
      @instances_slave.each {|instance| puts "Instance: #{instance.instance_id}, status: #{instance.status}"}

      # Return Slave Info (Struct) 
      @instances_slave.each {|instance| @slave_info.push(create_struct(instance))}
      return @slave_info
    end

#======================= get ip ======================#
    # Returns the Master IP or the Slaves IPs according to the 
    # isMaster value. 
    def get_ip(isMaster)
      # retrieve ip address
      ip_addr = Array.new(0)
      
      # Master or Slaves
      if isMaster == 1
        #puts "Master: #{@instances_master.size}"
        @instances_master.each { |instance|
          ip_addr.push(instance.ip_address)
        }
      else
        #puts "Slaves: #{@instances_slave.size}"
        @instances_slave.each { |instance|
          ip_addr.push(instance.ip_address)
        }
      end
  
      return ip_addr
    end
#======================= get dns ======================#
    # Returns the Master DNS or the Slaves DNS according to the 
    # isMaster value.     
    def get_dns(isMaster)
      # retrieve ip address
      dns_name = Array.new(0)
      
      # Master or Slaves
      if isMaster == 1
        @instances_master.each { |instance|
          dns_name.push(instance.dns_name)
        }
      else
        @instances_slave.each { |instance|
          dns_name.push(instance.dns_name)
        }
      end
  
      return dns_name
    end

#======================= get instance ======================#

    def get_instance()
      # retrieve instances
      return @instances
    end

#======================= terminate master ======================#
    # Terminates the Master Instance 
    def terminate_master()
      # terminate instance
      @instances_master.reverse.each { |instance|
        instance.terminate()
        puts "Terminating: #{instance.instance_id} Status: #{instance.status}"
      }

      # sleep until ready
      sleep 5 while @instances_master.any? {|instance| instance.status == :shutting_down}
      
      # Display Terminating Instances
      @instances_master.reverse.each { |instance| puts "Terminated instance #{instance.instance_id}, status: #{instance.status}"}
      
      # Check Instance Status
      exit 1 unless @instances_master.all? {|instance| instance.status == :terminated}
      
      # Display Instance Status
      @instances_master.reverse.each {|instance| puts "Instance: #{instance.instance_id}, status: #{instance.status}"}

      # empty instances
      @instances_master = Array.new(0)
    end

#======================= terminate slaves ======================#
    # Terminates the Slave Instances
    def terminate_slaves()
      # terminate instance
      @instances_slave.reverse.each { |instance|
        instance.terminate()
        puts "Terminating: #{instance.instance_id} Status: #{instance.status}"
      }

      # sleep until ready
      sleep 5 while @instances_slave.any? {|instance| instance.status == :shutting_down}
      
      # Display Terminating Instances
      @instances_slave.reverse.each { |instance| puts "Terminated instance #{instance.instance_id}, status: #{instance.status}"}
      
      # Check Instance Status
      exit 1 unless @instances_slave.all? {|instance| instance.status == :terminated}
      
      # Display Instance Status
      @instances_slave.reverse.each {|instance| puts "Instance: #{instance.instance_id}, status: #{instance.status}"}

      # empty instances
      @instances_slave = Array.new(0)
    end
    
#======================= send command ======================#
    # Send a command through SSH Shell to an instance. 
    # Need to pass instance object and the command as a string.     
def shell_command(instance, command)
  puts "executing shell command #{command}"
  begin
  Net::SSH.start(instance.ip_address, "ubuntu",
                 :key_data => [@key_pair.private_key]) do |ssh|
    channel = ssh.open_channel do |ch|
      ch.exec "#{command}" do |ch, success|
        raise "could not execute #{command}" unless success

        # "on_data" is called when the process writes something to stdout
        ch.on_data do |c, data|
          $stdout.print data
        end

        # "on_extended_data" is called when the process writes something to stderr
        ch.on_extended_data do |c, type, data|
          $stderr.print data
        end

        ch.on_close { puts "done!" }
      end
    end
  end
  rescue Net::SSH::HostKeyMismatch => e
     e.remember_host!
     puts "key mismatch, retry"
     sleep 1
     retry
  rescue SystemCallError, Timeout::Error => e
     # port 22 might not be available immediately after the instance finishes launching
     sleep 1
     # puts "Not Yet"
     retry
  end
end      

#======================= send command ======================#
    # Send a command through SSH to an instance. 
    # Need to pass instance object and the command as a string. 
    def send_command(instance, command)
      # send command to instance
      puts "Executing #{command}"
      begin
        Net::SSH.start(instance.ip_address, "ubuntu",
                       :key_data => [@key_pair.private_key]) do |ssh|
          puts "Running #{command} on the instance #{instance.instance_id}:"
          #ssh.exec!(command)
          ssh.exec(command)
          
        end
      rescue Net::SSH::HostKeyMismatch => e
        e.remember_host!
        puts "key mismatch, retry"
        sleep 1
        retry
      rescue SystemCallError, Timeout::Error => e
        # port 22 might not be available immediately after the instance finishes launching
        sleep 1
        # puts "Not Yet"
        retry
      end
    end
    
#======================= send command ======================#
    # Send a command through SSH to an instance. 
    # Need to pass instance object and the command as a string. 
    def send_command_blocking(instance, command)
      # send command to instance
      puts "Executing #{command}"
      begin
        Net::SSH.start(instance.ip_address, "ubuntu",
                       :key_data => [@key_pair.private_key]) do |ssh|
          puts "Running #{command} on the instance #{instance.instance_id}:"
          ssh.exec!(command)
          #ssh.exec(command)
          
        end
      rescue Net::SSH::HostKeyMismatch => e
        e.remember_host!
        puts "key mismatch, retry"
        sleep 1
        retry
      rescue SystemCallError, Timeout::Error => e
        # port 22 might not be available immediately after the instance finishes launching
        sleep 1
        # puts "Not Yet"
        retry
      end
    end
    
#======================= upload file ======================#
    # Uploads a file using SCP to an instance. 
    # Need to pass the instance object and the path to the file (Local and Remote). 
    def upload_file(instance, local_path, remote_path)
      # send command to instance
      puts "Uploading #{local_path} to instance #{instance.instance_id}"
      begin
        Net::SCP.start(instance.ip_address, "ubuntu",
                       :key_data => [@key_pair.private_key]) do |scp|
          puts "Uploading #{local_path} on the instance #{instance.instance_id}:"
          scp.upload! local_path, remote_path
        end
      rescue SystemCallError, Timeout::Error => e
        # port 22 might not be available immediately after the instance finishes launching
        sleep 1
        puts "Not Yet"
        retry
      rescue
        puts "unknown upload error, retry"
        sleep 1
        retry    
      end
    end    
#======================= get status ======================#

    def get_status()
      # 
      puts "status"
    end

#======================= clean up ======================#
    # Deletes the Key Pair and the Security Group Created. 
    def clean_up()
      # clean up
      @key_pair.delete()
      @group.delete()
    end

#======================= struct params ======================#

    def func()
      
    end 

  end

#======================= DONE WITH AWSINTERFACE CLASS DEFINITION ======================#
  
#======================= struct params ======================#
  # create_struct
  # Creates a struct with information about the instance. 
  def create_struct(instance)
    # Create Struct 
    instance_struct = Struct.new(:instance, :instance_id, :ip_address, :dns_name)
    # Return Struct with Master Info
    return instance_struct.new(instance, instance.instance_id, instance.ip_address, instance.dns_name)
  end
  
#======================= struct params ======================#
  # prepare_slave_script
  # Overrides a template file with Master Info (IP, DNS, HOSTNAME)
  # This creates the slave_script.txt that contains bash commands for the slaves. 
  def prepare_slave_script(file_name, master_ip, master_dns, master_hostname)
    file_template = "slave_script_template.sh"
    text = File.read(file_template)
    text = text.gsub(/MASTER_IP/, master_ip)
    #text = text.gsub(/MASTER_DNS/, master_dns)
    text = text.gsub(/MASTER_HOSTNAME/, master_hostname)
    File.open(file_name, "w") {|file| file.puts text}
  end

end # DONE WITH MODULE
