# First attempt at a ruby script to run all the steps necessary to
# create the 3 images needed for openstudio

# Note that this threadpool will equal the number of vms in the array
# there is no limit--so careful

# To run make sure that the vagrant aws and awsinfo plugin are installed

#    vagrant plugin install vagrant-aws
#    vagrant plugin install vagrant-awsinfo
# TODOs
#   - write out to logger
#   - use server-api gem to talk to AWS for API
#   - delete items that we don't want to rsync (but make sure not to delete them from git)

# This also uses the AWS gem in order to create the amazon image dynamically

require 'bundler'
Bundler.require(:default)

require 'thread'
require 'timeout'
require 'optparse'
require 'github'
require 'securerandom'

@options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: create_vms [options]"
  @options[:provider] = :vagrant
  @options[:version] = nil

  opts.on("-p", "--provider [name_of_provider]", String, "Name of provider [vagrant of aws]") do |s|
    @options[:provider] = s.to_sym
  end

  @options[:user_uuid] = SecureRandom.uuid
  opts.on("-u", "--user-id [uuid]", String, "User UUID to know which AMI/Instances are yours") do |s|
    @options[:user_uuid] = s
  end

  @options[:list_amis] = false
  opts.on("-l", "--list-amis", "Create AMI JSON lists") do |s|
    @options[:list_amis] = true
  end
end.parse!
puts "options = #{@options.inspect}"

if @options[:list_amis]
  puts "Listing available AMIs from AWS"

  require 'openstudio-aws'

  @aws = OpenStudio::Aws::Aws.new

  json_version_1 = @aws.os_aws.create_new_ami_json(1)
  json_version_2 = @aws.os_aws.create_new_ami_json(2)

  test_amis_filename = "amis_v1.json"
  File.delete(test_amis_filename) if File.exists?(test_amis_filename)
  File.open(test_amis_filename, 'w') { |f| f << JSON.pretty_generate(json_version_1) }

  test_amis_filename = "amis_v2.json"
  File.delete(test_amis_filename) if File.exists?(test_amis_filename)
  File.open(test_amis_filename, 'w') { |f| f << JSON.pretty_generate(json_version_2) }

  exit 0
end

# Versioning (change these each build) - Support old version lookup for awhile
if File.exist? "../server/lib/openstudio_server/version"
  require_relative "../server/lib/openstudio_server/version"
else
  require_relative "../server/lib/version"
end

@os_server_version = OpenstudioServer::VERSION + OpenstudioServer::VERSION_EXT
@os_version = nil
@os_version_sha = nil

os_role_file = "./chef/roles/openstudio.rb" # Grab the openstudio version out of the vagrant rols
if File.exists?(os_role_file)
  openstudio_role = File.read(os_role_file)
  json_string = openstudio_role.scan(/default_attributes\((.*)\)/m).first.join
  json_obj = eval("{ #{json_string} }")
  @os_version = json_obj[:openstudio][:version]
  @os_version_sha = json_obj[:openstudio][:installer][:version_revision]
else
  raise "Could not find OpenStudio.rb chef role in #{os_role_file}"
end

puts "OpenStudio Server Version is: #{@os_server_version}"
puts "OpenStudio Version is: #{@os_version}"
puts "OpenStudio SHA is: #{@os_version_sha}"
fail "OpenStudio Version / SHA is empty" if @os_version_sha.nil? || @os_version.nil?

test_amis_filename = "test_amis_openstudio.json"
File.delete(test_amis_filename) if File.exists?(test_amis_filename)

start_time = Time.now
puts "Lauching #{__FILE__} with provider: #{@options[:provider]}"

if @options[:provider] == :aws
  require 'aws-sdk'

  # read in the AWS config settings
  filename = File.expand_path(File.join("~", ".aws", "config.yml"))
  if File.exist? filename
    puts "Using new location style format"
    config = YAML.load(File.read(filename))
    AWS.config(
        :access_key_id => config['access_key_id'],
        :secret_access_key => config['secret_access_key'],
        :region => config['region'],
        :ssl_verify_peer => false
    )
  end

  @aws = AWS::EC2.new
end

# List of VMS to provision
@vms = []
if @options[:provider] == :vagrant
  @vms << {
      id: 1, name: "server", postflight_script_1: "configure_vagrant_server.sh", error_message: "",
      ami_name: "OpenStudio-Server OS-#{@os_version} V#{@os_server_version}"
  }
  @vms << {
      id: 2, name: "worker", postflight_script_1: "configure_vagrant_worker.sh", error_message: "",
      ami_name: "OpenStudio-Worker OS-#{@os_version} V#{@os_server_version}"
  }
  #@vms << {
  #    id: 3, name: "worker_2", postflight_script_1: "configure_vagrant_worker.sh", error_message: "",
  #    ami_name: "OpenStudio-Cluster OS-#{os_version} V#{os_server_version}"
  #}
elsif @options[:provider] == :aws
  @vms << {
      id: 1, name: "server", postflight_script_1: "setup-server-changes.sh", error_message: "",
      ami_name: "OpenStudio-Server OS-#{@os_version} V#{@os_server_version}"
  }
  @vms << {
      id: 2, name: "worker", postflight_script_1: "setup-worker-changes.sh", error_message: "",
      ami_name: "OpenStudio-Worker OS-#{@os_version} V#{@os_server_version}"
  }
  @vms << {
      id: 3, name: "worker_cluster", postflight_script_1: "setup-worker-changes.sh", error_message: "",
      ami_name: "OpenStudio-Cluster OS-#{@os_version} V#{@os_server_version}"
  }
end

$threads = []
$mutex = Mutex.new

class AllJobsInvalid < StandardError
end

def system_call(command, &block)
  IO.popen(command) do |io|
    while (line = io.gets) do
      yield line
    end
  end

  exit_code = $?.exitstatus
  puts "System call of #{command} exited with #{exit_code}"
  exit_code
end

# Run vagrant up with the provisioner
def run_vagrant_up(element)
  success = true
  $mutex.lock
  begin
    Timeout::timeout(4500) {
      puts "#{element[:id]}: starting process on #{element}"
      command = "cd ./#{element[:name]} && VAGRANT_AWS_USER_UUID=#{@options[:user_uuid]} vagrant up"
      if @options[:provider] == :aws
        command += " --provider=aws"
      end
      exit_code = system_call(command) do |message|
        puts "#{element[:id]}: #{message}"
        if message =~ /Installing Chef.*\d*.\d*.\d*.*Omnibus package.*/i
          puts "#{element[:id]}: Chef is installing - you can go on now"
          $mutex.unlock
        elsif message =~ /.*is already running/i
          puts "#{element[:id]}: machines already running -- go to vagrant provision"
          $mutex.unlock
        elsif message =~ /.*ERROR:/
          puts "#{element[:id]}: Error found during provisioning"
        end
      end
      if exit_code != 0
        # this can happen when AWS isn't available or insufficient capacity in AWS
        #InsufficientInstanceCapacity => Insufficient capacity.
        success = false
        # $mutex.unlock if $mutex.owned?
        # raise AllJobsInvalid # call this after unlocking
      end
    }
  rescue AllJobsInvalid
    # pass the exception through
    raise AllJobsInvalid
  rescue Timeout::Error
    # DO NOT raise an error if timeout, just timeout
    error = "#{element[:id]}: ERROR Timeout::Error running vagrant up"
    puts error
    element[:error_message] += error
    success = false
  rescue RuntimeError => e
    error = "#{element[:id]} #{e.message}"
    element[:error_message] += error
  rescue Exception => e
    # DO NOT raise an excpetion if it crashed out 
    error = "#{element[:id]}: ERROR in vagrant up with #{e.message}"
    puts error
    element[:error_message] += error
    success = false
  end
  $mutex.unlock if $mutex.owned?
  puts "#{element[:id]}: Finished vagrant up"

  success
end

def run_vagrant_provision(element)
  success = true
  $mutex.lock
  begin
    Timeout::timeout(4500) {
      puts "#{element[:id]}: entering provisioning (which requires syncing folders)"
      command = "cd ./#{element[:name]} && vagrant provision"
      exit_code = system_call(command) do |message|
        puts "#{element[:id]}: #{message}"
        if message =~ /Running provisioner. chef_solo.../i
          puts "#{element[:id]}: chef running - you can go on now"
          $mutex.unlock
        elsif message =~ /The machine is already created/i
          puts "#{element[:id]}: machines already running -- go to vagrant provision"
          $mutex.unlock
        elsif message =~ /.*ERROR:/
          puts "Error found during provisioning"
        end
      end
      if exit_code != 0
        success = false
      end
    }
  rescue Timeout::Error
    # DO NOT raise an error if timeout, just timeout
    error = "#{element[:id]}: ERROR Timeout::Error running vagrant provision"
    puts error
    element[:error_message] += error
    success = false
  rescue NameError => e
    error = "#{element[:id]} #{e.message}"
    element[:error_message] += error
  rescue Exception => e
    # DO NOT raise an excpetion if it crashed out 
    error = "#{element[:id]}: ERROR provisioning box with #{e.message}"
    puts error
    element[:error_message] += error
    success = false
  end
  puts "#{element[:id]}: Finished provisioning"
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
  rescue => e
    error = "Error running vagrant reload, #{e.message}"
    puts error
    element[:error_message] += error
    raise error # make sure to raise error to crash out the provisioning
  end
  puts "#{element[:id]}: finished restarting"
  $mutex.unlock
end

# Get the instance IDs using the AWS info plugin
def get_instance_id(element)
  $mutex.lock
  puts "#{element[:id]}: Get instance id"
  begin
    Timeout::timeout(60) {
      command = "cd ./#{element[:name]} && vagrant awsinfo"
      r = JSON.parse `#{command}`
      element[:instance_id] = r['instance_id']
    }
  rescue => e
    error ="Error running get instance_id, #{e.message}: #{e.backtrace.join('\n')}"
    puts error
    element[:error_message] += error
    raise error
  end
  puts "#{element[:id]}: Finished getting instance ID #{element[:instance_id]}"
  $mutex.unlock
end

def create_ami(element)
  i = nil
  begin
    # Call the method to create the AMIs
    puts "#{element[:id]}: creating AMI #{element[:ami_name]}"
    i = @aws.images.create(instance_id: element[:instance_id], name: element[:ami_name])
    puts "#{element[:id]}: waiting for AMI to become available"
    while (i.state != :available) && (i.state != :failed) do
      puts "#{element[:id]}: ..."
      sleep 5
    end
    puts "#{element[:id]}: finished create_ami block with result #{i.inspect}"
  rescue Exception => e
    puts "#{element[:id]}: expection during AMI generation with #{e.message}"
    i = nil
  end

  return i
end

def process(element, &block)
  begin
    # Only starts the machine and mounts the drives, but does not call provision
    run_vagrant_up(element)

    # Call this up to 3 times
    retries = 0
    while true
      retries += 1
      if retries <= 3
        success = run_vagrant_provision(element)
        break if success
      else
        raise "ERROR reached maximum number of retries in vagrant provision"
      end
    end

    # run vagrant provision one more time to make sure that it completes (mainly to catch the passenger error)
    # run_vagrant_provision(element)

    # Append the instance id to the element
    if @options[:provider] == :aws
      get_instance_id(element)
    end

    begin
      Timeout::timeout(1200) {
        # cleanup the box by calling the cleanup scripts
        puts "#{element[:id]}: configuring the machines"
        command = "cd ./#{element[:name]} && vagrant ssh -c 'chmod +x /data/launch-instance/*.sh'"
        system_call(command) { |message| puts "#{element[:id]}: #{message}" }
        command = "cd ./#{element[:name]} && vagrant ssh -c '/data/launch-instance/#{element[:postflight_script_1]}'"
        system_call(command) { |message| puts "#{element[:id]}: #{message}" }
      }
    rescue Exception => e
      raise Timeout::Error, "Timeout::Error running initial cleanup, #{e.message}"
    end

    if @options[:provider] == :aws
      # Reboot the box if on Amazon because of kernel updates
      #run_vagrant_reload(element) # TODO: can i remove this?

      # finish up AMI cleanup 
      begin
        Timeout::timeout(1200) {
          command = "cd ./#{element[:name]} && vagrant ssh -c 'chmod +x /data/launch-instance/*.sh'"
          #system_call(command) { |message| puts "#{element[:id]}: #{message}" }
          command = "cd ./#{element[:name]} && vagrant ssh -c '/data/launch-instance/setup-final-changes.sh'"
          #system_call(command) { |message| puts "#{element[:id]}: #{message}" }
        }
      rescue Exception => e
        raise Timeout::Error, "Timeout::Error running final cleanup, #{e.message}"
      end

      begin
        Timeout::timeout(1800) {
          i = create_ami(element)
          # check if the ami was create--if not change the ami_name and rerun    
          if i.nil? || i.state == :failed
            puts "#{element[:id]}: AMI creation failed, retrying"
            retries = 0
            while retries < 3
              retries += 1

              element[:ami_name] += Time.now.strftime(" %Y%m%d-%H%M%S")
              i = create_ami(element)
              # update the name of the ami in case the old one is still around
              break if i && i.state == :available
            end
          end

          if i
            if i.state == :available
              puts "#{element[:id]}: making new AMI public"
              i.public = true
              element[:ami_id] = i.image_id
              i.add_tag("autobuilt")
              i.add_tag("created", :value => true)
              i.add_tag("tested", :value => false)
              i.add_tag("created_on", :value => Time.now)
              i.add_tag("openstudio_server_version", :value => @os_server_version)
              i.add_tag("openstudio_version", :value => @os_version)
              i.add_tag("openstudio_version_sha", :value => @os_version_sha)
              i.add_tag("user_uuid", :value => @options[:user_uuid])
              puts "#{element[:id]}: finished creating AMI"
            end
          else
            element[:error_message] += "AMI did not get created"
          end
        }
      rescue Exception => e
        raise "Error creating AMI. #{e.message}, #{e.backtrace}"
      end
    end

    # Do some testing the machines in the future, otherwise, if it got here it is assumed good
    element[:good_ami] = true
  rescue AllJobsInvalid
    element[:good_ami] = false
    element[:error_message] += "One of the images failed, killing all threads"

    puts "Found error in one of the images therefore killing all threads"
    $threads.each { |t| t.exit }
  rescue Exception => e
    puts e.message
    # make it clear that the setup is invalid
    element[:good_ami] = false
    element[:error_message] += "Exception message, #{e.message}, #{e.backtrace}"
  ensure
    # Be sure to alwys kill the instances if using AWS
    if @options[:provider] == :aws
      puts "#{element[:id]}: terminating instance"
      command = "cd ./#{element[:name]} && vagrant destroy -f"
      system_call(command) { |message| puts "#{element[:id]}: #{message}" }
      puts "#{element[:id]}: instance terminated and  thread"
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


puts
puts "============================= AMI Information======================================="
puts
@vms.each do |vm|
  puts vm
end
puts
puts "===================================================================="
puts
puts "===================================================================="
puts
end_time = Time.now
good_build = @vms.all? { |vm| vm[:good_ami] && vm[:error_message] == "" }
if good_build
  puts "All machines appear to be good"

  if @options[:provider] == :aws
    puts
    puts "=========================== JSON ========================================="
    amis_hash = {}
    amis_hash[@os_version] = {}
    amis_hash[@os_version]["server"] = @vms.select { |vm| vm[:name] == "server_aws" }.first[:ami_id]
    amis_hash[@os_version]["worker"] = @vms.select { |vm| vm[:name] == "worker_aws" }.first[:ami_id]
    amis_hash[@os_version]["cc2worker"] = @vms.select { |vm| vm[:name] == "worker_cluster" }.first[:ami_id]

    puts JSON.pretty_generate(amis_hash)

    puts "Saving ami infomration to file"
    outfile = File.join(File.dirname(__FILE__), test_amis_filename)
    # save it to a file for use in integration test
    File.open(outfile, 'w') { |f| f << JSON.pretty_generate(amis_hash) }
  end
else
  puts "AMIs had errors"
  exit 1
end
puts
puts "Took #{end_time - start_time}s to build."
exit 0
