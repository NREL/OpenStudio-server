# This ruby script shows how to use the classAWS.rb class to launch the Server and Worker nodes
# on EC2. After the servers are configures, the latter part of the script uses the API to
# run an example analysis.

require "./AwsConfig.rb"
require "json"

# use the aws class that lives in the OpenStudio Repository now.  Make sure to update the PATH below to
# whereever you OpenStudio checkout is (currently on the AWSProvider branch in OS)
#OS_PATH = "C:/Projects/OpenStudio"
OS_PATH = "/Users/nlong/Working/OpenStudio"

# Global Options
CREATE_SERVER=true
CREATE_WORKER=true
WORKER_INSTANCES=1
TEST_SSH=true

# read in the config.yml file to get the secret/private key
config = AwsConfig.new()

# Launch the master
if CREATE_SERVER
  instance_data = {instance_type: "m2.xlarge" }
  #instance_data = {instance_type: "t1.micro" }
  instance_string = instance_data.to_json.gsub("\"", "\\\\\"")

  start_string = "ruby #{OS_PATH}/openstudiocore/ruby/cloud/aws.rb.in #{config.access_key} #{config.secret_key} us-east-1 EC2 launch_server \"#{instance_string}\""
  puts "#{start_string}"
  server_data_str = `#{start_string}`
  puts server_data_str
  server_data = JSON.parse(server_data_str, :symbolize_names => true)

  # Save off the private key for later access
  server_key_file = "ec2_server_key.pem"
  File.open(server_key_file, "w") { |f| f << server_data[:private_key] }
  File.chmod(0600, server_key_file)

  # Save off the server data to be loaded into the worker nodes.  The Private key needs to e read from a
  # file in the worker node, so save that name instead in the HASH along with a couple other changes
  server_data[:private_key] = server_key_file
  server_data[:server_id] = server_data[:server][:id]
  server_data[:server_ip] = server_data[:server][:ip]
  server_data[:server_dns] = server_data[:server][:dns]
  File.open("server_data.json", "w") { |f| f << JSON.pretty_generate(server_data) }

  # Print out some debugging commands (probably work on mac/linux only)
  puts ""
  puts "Server SSH Command:"
  puts "ssh -i #{server_key_file} ubuntu@#{server_data[:server][:dns]}"
end

# Launch the workers
if CREATE_WORKER
  server_json = JSON.parse(File.read("server_data.json"), :symbolize_names => true)

  # How many instances?
  #server_json[:instance_type] = "cc2.8xlarge"
  server_json[:instance_type] = "m2.xlarge"
  #server_json[:instance_type] = "t1.micro"
  server_json[:num] = WORKER_INSTANCES
  server_string = server_json.to_json.gsub("\"", "\\\\\"")

  start_string = "ruby #{OS_PATH}/openstudiocore/ruby/cloud/aws.rb.in #{config.access_key} #{config.secret_key} us-east-1 EC2 launch_workers \"#{server_string}\""
  worker_data_string = `#{start_string}`
  worker_data = JSON.parse(worker_data_string, :symbolize_names => true)
  File.open("worker_data.json", "w") { |f| f << JSON.pretty_generate(worker_data) }

  # Print out some debugging commands (probably work on mac/linux only)
  worker_data[:workers].each do |worker|
    puts ""
    puts "Worker SSH Command:"
    puts "ssh -i #{server_json[:private_key]} ubuntu@#{worker[:dns]}"
  end
end

### Debugging section


if TEST_SSH
  # This is taken out of the OpenStudio AWS config file to do some testing
  def send_command(host, command, key)
    require 'net/http'
    require 'net/scp'
    require 'net/ssh'

    retries = 0
    begin
      puts "connecting.."
      output = ''
      Net::SSH.start(host, 'ubuntu', :key_data => [key]) do |ssh|
        response = ssh.exec!(command)
        output += response if !response.nil?
      end
      return output
    rescue Net::SSH::HostKeyMismatch => e
      e.remember_host!
      # key mismatch, retry
      return if retries == 2
      retries += 1
      sleep 1
      retry
    rescue Net::SSH::AuthenticationFailed
      error(-1, "Incorrect private key")
    rescue SystemCallError, Timeout::Error => e
      # port 22 might not be available immediately after the instance finishes launching
      return if retries == 2
      retries += 1
      sleep 1
      retry
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
    end
  end

  server_json = JSON.parse(File.read("server_data.json"), :symbolize_names => true)
  #puts send_command(server_json[:server_ip], 'nproc | tr -d "\n"', File.read("ec2_server_key.pem"))
end

