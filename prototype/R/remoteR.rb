require 'rubygems'
require 'net/http'
require 'net/ssh'
require 'net/scp'

module RInterface 
  class Rtest
#======================= send command ======================#
    # Send a command through SSH to an instance. 
    # Need to pass instance object and the command as a string. 
    def send_command(command)
      # send command to instance
      puts "Executing #{command}"
      begin
        Net::SSH.start('192.168.33.10', 'vagrant',
                       :password => "vagrant") do |ssh|
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
    
  end
end

