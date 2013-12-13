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
#   - return an overall status of each AMI (did it error out?)
#   - i don't think the writing back to the VM array hash is threadsafe... check it
#   - add timeout on thread

# This also uses the AWS gem in order to create the amazon image dynamically
require 'aws-sdk'
require 'thread'

# Versioning (change these each build)
os_version = "1.1.4"
os_server_version= "1.3.1d"


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
    {id: 1, name: "server_aws", cleanup: "setup-server-changes.sh", ami_name: "OpenStudio-Server OS-#{os_version} V#{os_server_version}"},
    {id: 2, name: "worker_aws", cleanup: "setup-worker-changes.sh", ami_name: "OpenStudio-Worker OS-#{os_version} V#{os_server_version}"},
    {id: 3, name: "worker_cluster_aws", cleanup: "setup-worker-changes.sh", ami_name: "OpenStudio-Cluster OS-#{os_version} V#{os_server_version}"}
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

def process(element, &block)
  begin
    puts "#{element[:id]}: starting process on #{element}"
    $mutex.lock
    puts "#{element[:id]}: entering mutex section"
    command = "cd ./#{element[:name]} && vagrant up --provider=aws"
    system_call(command) do |message|
      puts "#{element[:id]}: #{message}"
      if message =~ /Running chef-solo.../i
        yield "#{element[:id]}: chef running - you can go on now"
        $mutex.unlock
      elsif message =~ /The machine is already created/i
        yield "#{element[:id]}: machines already running -- go to vagrant provision"
        $mutex.unlock
      end
    end
    $mutex.unlock if $mutex.owned?
    puts "#{element[:id]}: chef is complete"

    # Reprovision (how many times?)
    2.times {
      $mutex.lock
      puts "#{element[:id]}: entering reprovisioning (which requires Rsyncing again)"
      command = "cd ./#{element[:name]} && vagrant provision"
      system_call(command) do |message|
        puts "#{element[:id]}: #{message}"
        if message =~ /Running chef-solo.../i
          yield "#{element[:id]}: chef running - you can go on now"
          $mutex.unlock
        elsif message =~ /The machine is already created/i
          yield "#{element[:id]}: machines already running -- go to vagrant provision"
          $mutex.unlock
        end
      end
      puts "#{element[:id]}: finished reprovisioning"
      $mutex.unlock if $mutex.owned?
    }

    # Get the instance ids by executing the Amazon API on the system. I don't thinks need to have mutexes?
    puts "#{element[:id]}: Get instance id"
    command = "cd ./#{element[:name]} && vagrant ssh -c 'curl -sL http://169.254.169.254/latest/meta-data/instance-id'"
    element[:instance_id] = `#{command}`
    puts "#{element[:id]}: Finished getting element ID"

    # cleanup the box by calling the cleanup scripts
    #$mutex.lock # i don't think we have to lock these, but i am not sure about virtualbox and multiple hits with vagrant ssh
    puts "#{element[:id]}: cleaning up the machines"
    command = "cd ./#{element[:name]} && vagrant ssh -c 'chmod +x /data/launch-instance/*.sh'"
    system_call(command) { |message| puts "#{element[:id]}: #{message}" }
    command = "cd ./#{element[:name]} && vagrant ssh -c '/data/launch-instance/#{element[:cleanup]}'"
    system_call(command) { |message| puts "#{element[:id]}: #{message}" }
    $mutex.lock
    command = "cd ./#{element[:name]} && vagrant reload"
    system_call(command) { |message| puts "#{element[:id]}: #{message}" }
    $mutex.unlock
    command = "cd ./#{element[:name]} && vagrant ssh -c 'chmod +x /data/launch-instance/*.sh'"
    system_call(command) { |message| puts "#{element[:id]}: #{message}" }
    command = "cd ./#{element[:name]} && vagrant ssh -c '/data/launch-instance/setup-final-changes.sh'"
    system_call(command) { |message| puts "#{element[:id]}: #{message}" }

    # Call the method to create the AMIs
    puts "#{element[:id]}: creating AMI"
    begin
      i = @aws.images.create(instance_id: element[:instance_id], name: element[:ami_name])
      puts "#{element[:id]}: waiting for AMI to become available"
      while i.state != :available do
        puts "."
        sleep 5
      end
      puts "#{element[:id]}: making new AMI public"
      i.public = true
    rescue AWS::EC2::Errors::InvalidAMIName::Duplicate => e
      puts "#{element[:id]}: error creating AMI #{e.message}"
    rescue Exception => e
      puts "#{element[:id]}: error creating AMI #{e.message}"
    end
    puts "#{element[:id]}: finished creating AMI"

  ensure
    puts "#{element[:id]}: terminating instance"
    command = "cd ./#{element[:name]} && vagrant destroy -f"
    system_call(command) { |message| puts "#{element[:id]}: #{message}" }
    puts "#{element[:id]}: instance terminsated and exiting thread"
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

puts vms.inspect


