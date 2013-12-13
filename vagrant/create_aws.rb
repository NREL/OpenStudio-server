# First attempt at a ruby script to run all the steps necessary to
# create the 3 images needed for openstudio

# Note that this threadpool will equal the number of vms in the array
# there is no limit--so careful

# TODOs
#   - write out to logger
#   - use server-api gem to talk to AWS for API
#   - add additional tags to AMIs
#   - print out JSON at the end in the format of the amis.json on developer
#   - delete items that we don't want to rsync (but make sure not to delete them from git)
#   - i don't think the writing back to the VM array hash is threadsafe... check it

# This also uses the AWS gem in order to create the amazon image dynamically
require 'aws-sdk'
require 'thread'

# Versioning (change these each build)
os_version = "1.1.4"
os_server_version= "1.3.1"
revision_id = "" # with preceding . 


# read in the AWS config settings
config = YAML.load(File.read(File.join(File.expand_path("~"), "aws_config.yml")))
AWS.config(
    :access_key_id => config['access_key_id'],
    :secret_access_key => config['secret_access_key'],
    :region => "us-east-1",
    :ssl_verify_peer => false
)
@aws = AWS::EC2.new

vms = [
    {id: 1, name: "server_aws", cleanup: "setup-server-changes.sh", ami_name: "OpenStudio-Server OS-#{os_version} V#{os_server_version}#{revision_id}"},
    {id: 2, name: "worker_aws", cleanup: "setup-worker-changes.sh", ami_name: "OpenStudio-Worker OS-#{os_version} V#{os_server_version}#{revision_id}"},
    {id: 3, name: "worker_cluster_aws", cleanup: "setup-worker-changes.sh", ami_name: "OpenStudio-Cluster OS-#{os_version} V#{os_server_version}#{revision_id}"}
]

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
  $mutex.lock
  begin
    Timeout::timeout(1800) {
      puts "#{element[:id]}: starting process on #{element}"
      command = "cd ./#{element[:name]} && vagrant up --provider=aws"
      system_call(command) do |message|
        puts "#{element[:id]}: #{message}"
        if message =~ /Running chef-solo.../i
          puts "#{element[:id]}: chef running - you can go on now"
          $mutex.unlock
        elsif message =~ /The machine is already created/i
          puts "#{element[:id]}: machines already running -- go to vagrant provision"
          $mutex.unlock
        end
      end
    }
  rescue Exception => e
    raise TimeoutError, "Error running vagrant up, #{e.message}"
  end
  $mutex.unlock if $mutex.owned?
  puts "#{element[:id]}: chef is running"
end

def run_vagrant_reprovision(element)
  $mutex.lock
  begin
    Timeout::timeout(1800) {
      puts "#{element[:id]}: entering reprovisioning (which requires Rsyncing again)"
      command = "cd ./#{element[:name]} && vagrant provision"
      system_call(command) do |message|
        puts "#{element[:id]}: #{message}"
        if message =~ /Running chef-solo.../i
          puts "#{element[:id]}: chef running - you can go on now"
          $mutex.unlock
        elsif message =~ /The machine is already created/i
          puts "#{element[:id]}: machines already running -- go to vagrant provision"
          $mutex.unlock
        end
      end
    }
  rescue Exception => e
    raise TimeoutError, "Error running vagrant provision, #{e.message}"
  end
  puts "#{element[:id]}: finished reprovisioning"
  $mutex.unlock if $mutex.owned?
end

def run_vagrant_reload(element)
  $mutex.lock
  begin
    Timeout::timeout(900) {
      puts "#{element[:id]}: restarting instance using vagrant reload"
      command = "cd ./#{element[:name]} && vagrant reload"
      system_call(command) { |message| puts "#{element[:id]}: #{message}" }
    }
  rescue Exception => e
    raise TimeoutError, "Error running vagrant reload, #{e.message}"
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
    raise TimeoutError, "Error running get instance_id, #{e.message}"
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
    puts "."
    sleep 5
  end

  return i
end

def process(element, &block)
  begin
    run_vagrant_up(element)
    # Reprovision (how many times?)
    2.times {
      run_vagrant_reprovision(element)
    }

    get_instance_id(element)

    begin
      Timeout::timeout(900) {
        # cleanup the box by calling the cleanup scripts
        puts "#{element[:id]}: cleaning up the machines"
        command = "cd ./#{element[:name]} && vagrant ssh -c 'chmod +x /data/launch-instance/*.sh'"
        #system_call(command) { |message| puts "#{element[:id]}: #{message}" }
        command = "cd ./#{element[:name]} && vagrant ssh -c '/data/launch-instance/#{element[:cleanup]}'"
        #system_call(command) { |message| puts "#{element[:id]}: #{message}" }
      }
    rescue Exception => e
      raise TimeoutError, "Error running initial cleanup, #{e.message}"
    end

    run_vagrant_reload(element)

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
          i.add_tag("autobuild")
          i.add_tag("sucessfully_created")
          puts "#{element[:id]}: finished creating AMI"
        end
      }
    rescue Exception => e
      raise TimeoutError, "Error creating AMI. AMI state: #{i.state}, #{e.message}"
    end

    # Do some testing of the AMI in the future, otherwise, if it got here it is assumed good
    element[:good_ami] = true
  rescue Exception => e
    puts e.message

    # make it clear that the setup is invalid
    element[:good_ami] = false
    element[:error_message] = e.message
  ensure
    puts "#{element[:id]}: terminating instance"
    command = "cd ./#{element[:name]} && vagrant destroy -f"
    system_call(command) { |message| puts "#{element[:id]}: #{message}" }
    puts "#{element[:id]}: instance terminated and exiting thread"
  end
end

vms.each do |vm|
  $threads << Thread.new do
    process(vm) do |status|
      puts status
    end
  end
end
$threads.each { |t| t.join }

vms.each do |vm|
  puts vm
end

puts "================"
good_build = vms.all? { |vm| vm[:good_ami] }
if good_build
  puts "All AMIs appear to be good"
  puts
  puts " === amis.json format ====="

  amis_hash = {}
  amis_hash[os_version] = {}
  amis_hash[os_version]["server"] = vms.select { |vm| vm[:name] == "server_aws" }.first[:ami_id]
  amis_hash[os_version]["worker"] = vms.select { |vm| vm[:name] == "worker" }.first[:ami_id]
  amis_hash[os_version]["cc2worker"] = vms.select { |vm| vm[:name] == "worker_aws" }.first[:ami_id]

  puts JSON.pretty_generate(amis_hash.to_json)
else
  puts "AMIs had errors"
end






