# First attempt at a ruby script to run all the steps necessary to
# create the 3 images needed for openstudio

# Note that this threadpool will equal the number of vms in the array
# there is no limit--so careful

# TODOs
#   - write out to logger
#   - use server-api gem to talk to AWS for API
#   - delete items that we don't want to rsync (but make sure not to delete them from git)

# This also uses the AWS gem in order to create the amazon image dynamically

require 'thread'

# Versioning (change these each build)
os_version = "1.1.3"
os_server_version= "1.2.0"
revision_id = "" # with preceding . 

@provider = "vagrant".to_sym
if ARGV[0]
  if ARGV[0] == "aws"
    @provider = "aws".to_sym
  end
end

if @provider == :aws
  require 'aws-sdk'

  # read in the AWS config settings
  config = YAML.load(File.read(File.join(File.expand_path("~"), "aws_config.yml")))
  AWS.config(
      :access_key_id => config['access_key_id'],
      :secret_access_key => config['secret_access_key'],
      :region => "us-east-1",
      :ssl_verify_peer => false
  )
  @aws = AWS::EC2.new
end

# List of VMS to provision
@vms = []
if @provider == :vagrant
  vms << {
      id: 1, name: "server", postflight_script_1: "configure_vagrant_server.sh", error_message: "",
      ami_name: "OpenStudio-Server OS-#{os_version} V#{os_server_version}#{revision_id}"
  }
  vms << {
      id: 2, name: "worker", postflight_script_1: "configure_vagrant_worker.sh", error_message: "",
      ami_name: "OpenStudio-Worker OS-#{os_version} V#{os_server_version}#{revision_id}"
  }
  vms << {
      id: 3, name: "worker_2", postflight_script_1: "configure_vagrant_worker.sh", error_message: "",
      ami_name: "OpenStudio-Cluster OS-#{os_version} V#{os_server_version}#{revision_id}"
  }
elsif @provider == :aws
  vms << {
      id: 1, name: "server_aws", postflight_script_1: "setup-server-changes.sh",
      ami_name: "OpenStudio-Server OS-#{os_version} V#{os_server_version}#{revision_id}"
  }
  vms << {
      id: 2, name: "worker_aws", postflight_script_1: "setup-worker-changes.sh",
      ami_name: "OpenStudio-Worker OS-#{os_version} V#{os_server_version}#{revision_id}"
  }
  vms << {
      id: 3, name: "worker_cluster_aws", postflight_script_1: "setup-worker-changes.sh",
      ami_name: "OpenStudio-Cluster OS-#{os_version} V#{os_server_version}#{revision_id}"
  }
end

$threads = []
$mutex = Mutex.new

def system_call(command, &block)
  IO.popen(command) do |io|
    while (line = io.gets) do
      yield line
    end
  end
end

def run_vagrant_up(element)
  success = true
  $mutex.lock
  begin
    Timeout::timeout(2400) {
      puts "#{element[:id]}: starting process on #{element}"
      command = "cd ./#{element[:name]} && vagrant up"
      if @provider == :aws
        command += " --provider=aws"
      end
      system_call(command) do |message|
        puts "#{element[:id]}: #{message}"
        if message =~ /Running chef-solo.../i
          puts "#{element[:id]}: chef running - you can go on now"
          $mutex.unlock
        elsif message =~ /The machine is already created/i
          puts "#{element[:id]}: machines already running -- go to vagrant provision"
          $mutex.unlock
        elsif message =~ /.*ERROR:/
          puts "Error found during provisioning"
        end
      end
    }
  rescue TimeoutError
    # DO NOT raise an error if timeout, just timeout
    error = "#{element[:id]}: ERROR TimeoutError running vagrant up"
    puts error
    element[:error_message] += error
    success = false
  rescue Exception => e
    # DO NOT raise an excpetion if it crashed out 
    puts "#{element[:id]}: ERROR in vagrant up with #{e.message}"
    puts error
    element[:error_message] += error
    success = false
  end
  $mutex.unlock if $mutex.owned?
  puts "#{element[:id]}: Finished vagrant up"

  success
end

def run_vagrant_reprovision(element)
  success = false
  $mutex.lock
  begin
    Timeout::timeout(2400) {
      puts "#{element[:id]}: entering provisioning (which requires syncing folders)"
      command = "cd ./#{element[:name]} && vagrant provision"
      system_call(command) do |message|
        puts "#{element[:id]}: #{message}"
        if message =~ /Running chef-solo.../i
          puts "#{element[:id]}: chef running - you can go on now"
          $mutex.unlock
        elsif message =~ /The machine is already created/i
          puts "#{element[:id]}: machines already running -- go to vagrant provision"
          $mutex.unlock
        elsif message =~ /.*ERROR:/
          puts "Error found during provisioning"
        end
      end
      success = true
    }
  rescue TimeoutError
    # DO NOT raise an error if timeout, just timeout
    error = "#{element[:id]}: ERROR TimeoutError running vagrant provision"
    puts error
    element[:error_message] += error
    success = false
  rescue Exception => e
    # DO NOT raise an excpetion if it crashed out 
    error = "#{element[:id]}: ERROR reprovisioning box with #{e.message}"
    puts error
    element[:error_message] += error
    success = false
  end
  puts "#{element[:id]}: Finished reprovisioning"
  $mutex.unlock if $mutex.owned?

  success
end

def run_vagrant_reload(element)
  $mutex.lock
  begin
    Timeout::timeout(1800) {
      puts "#{element[:id]}: restarting instance using vagrant reload"
      command = "cd ./#{element[:name]} && vagrant reload"
      system_call(command) { |message| puts "#{element[:id]}: #{message}" }
    }
  rescue Exception => e
    error = "Error running vagrant reload, #{e.message}"
    puts error
    element[:error_message] += error
    raise error # make sure to raise error to crash out the provisioning
  end
  puts "#{element[:id]}: finished restarting"
  $mutex.unlock
end

def get_instance_id(element)
  # Get the instance ids by executing the Amazon API on the system. I don't thinks need to have mutexes?
  puts "#{element[:id]}: Get instance id"
  begin
    Timeout::timeout(60) {
      command = "cd ./#{element[:name]} && vagrant ssh -c 'curl -sL http://169.254.169.254/latest/meta-data/instance-id'"
      element[:instance_id] = `#{command}`
    }
  rescue Exception => e
    error ="Error running get instance_id, #{e.message}"
    puts error
    element[:error_message] += error
    raise TimeoutError, error
  end
  puts "#{element[:id]}: Finished getting element ID"
end

def create_ami(element)
  i = nil
  # Call the method to create the AMIs
  puts "#{element[:id]}: creating AMI #{element[:ami_name]}"
  i = @aws.images.create(instance_id: element[:instance_id], name: element[:ami_name])
  puts "#{element[:id]}: waiting for AMI to become available"
  while (i.state != :available) && (i.state != :failed) do
    puts "#{element[:id]}: ..."
    sleep 5
  end

  return i
end

def process(element, &block)
  begin
    # starts and call provision if now. If it is already running it just says running...
    run_vagrant_up(element)

    # Reprovision (how many times?)
    2.times {
      run_vagrant_reprovision(element) # how do we test that this was successful?
    }

    # Append the instance id to the element
    if @provider == :aws
      get_instance_id(element)
    end

    begin
      Timeout::timeout(900) {
        # cleanup the box by calling the cleanup scripts
        puts "#{element[:id]}: configuring the machines"
        command = "cd ./#{element[:name]} && vagrant ssh -c 'chmod +x /data/launch-instance/*.sh'"
        system_call(command) { |message| puts "#{element[:id]}: #{message}" }
        command = "cd ./#{element[:name]} && vagrant ssh -c '/data/launch-instance/#{element[:postflight_script_1]}'"
        system_call(command) { |message| puts "#{element[:id]}: #{message}" }
      }
    rescue Exception => e
      raise TimeoutError, "Error running initial cleanup, #{e.message}"
    end

    # Reboot the box if on Amazon because of kernel updates
    if @provider == :aws
      run_vagrant_reload(element)
    end

    # finish up AMI cleanup 
    if @provider == :aws
      begin
        Timeout::timeout(900) {
          command = "cd ./#{element[:name]} && vagrant ssh -c 'chmod +x /data/launch-instance/*.sh'"
          #system_call(command) { |message| puts "#{element[:id]}: #{message}" }
          command = "cd ./#{element[:name]} && vagrant ssh -c '/data/launch-instance/setup-final-changes.sh'"
          #system_call(command) { |message| puts "#{element[:id]}: #{message}" }
        }
      rescue Exception => e
        raise TimeoutError, "Error running final cleanup, #{e.message}"
      end

      begin
        Timeout::timeout(900) {
          i = create_ami(element)
          # check if the ami was create--if not change the ami_name and rerun    
          if i.nil? || i.state == :failed
            retries = 0
            while retries < 3 && i.state == :available
              retries += 1
              # update the name of the ami in case the old one is still around
              element[:ami_name] += Time.now.strftime("%Y%m%d-%H%M%S")
              i = create_ami(element)
            end
          end

          if i.state == :available
            puts "#{element[:id]}: making new AMI public"
            i.public = true
            element[:ami_id] = i.image_id
            i.add_tag("autobuilt")
            i.add_tag("sucessfully_created", :value => true)
            puts "#{element[:id]}: finished creating AMI"
          end
        }
      rescue Exception => e
        raise TimeoutError, "Error creating AMI. AMI state: #{i.state}, #{e.message}"
      end
    end


    # Do some testing the machines in the future, otherwise, if it got here it is assumed good
    element[:good_ami] = true
  rescue Exception => e
    puts e.message

    # make it clear that the setup is invalid
    element[:good_ami] = false
    element[:error_message] += "Exception message, #{e.message}"
  ensure
    # Be sure to alwys kill the instances if using AWS
    if @provider == :aws
      puts "#{element[:id]}: terminating instance"
      command = "cd ./#{element[:name]} && vagrant destroy -f"
      system_call(command) { |message| puts "#{element[:id]}: #{message}" }
      puts "#{element[:id]}: instance terminated and exiting thread"
    end
  end
end

@vms.each do |vm|
  $threads << Thread.new do
    process(vm) do |status|
      puts status
    end
  end
end
$threads.each { |t| t.join }

@vms.each do |vm|
  puts vm
end

puts "================"
good_build = @vms.all? { |vm| vm[:good_ami] }
if good_build
  puts "All machines appear to be good"

  if @provider == :aws
    puts
    puts " === amis.json format ====="
    amis_hash = {}
    amis_hash[os_version] = {}
    amis_hash[os_version]["server"] = vms.select { |vm| vm[:name] == "server_aws" }.first[:ami_id]
    amis_hash[os_version]["worker"] = vms.select { |vm| vm[:name] == "worker_aws" }.first[:ami_id]
    amis_hash[os_version]["cc2worker"] = vms.select { |vm| vm[:name] == "worker_cluster_aws" }.first[:ami_id]

    puts JSON.pretty_generate(amis_hash.to_json)
  end
else
  puts "AMIs had errors"
end
