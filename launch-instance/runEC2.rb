# This ruby script shows how to use the aws.rb.in class in OpenStudio to launch the Server and Worker nodes
# on EC2. After the servers are configures, the latter part of the script uses the API to
# run an example analysis.

# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'
                              
require 'openstudio-aws'

# Global Options
WORKER_INSTANCES=2

#require 'openstudio-aws'
aws = OpenStudio::Aws::Aws.new()
#server_options = {instance_type: "t1.micro" }
server_options = {instance_type: "m1.small" }
#server_options = {instance_type: "m2.xlarge" }

worker_options = {instance_type: "m1.small" }
#worker_options = {instance_type: "m2.xlarge" }
#worker_options = {instance_type: "m2.2xlarge" }
#worker_options = {instance_type: "m2.4xlarge" }
#worker_options = {instance_type: "cc2.8xlarge" }

# Create the server
aws.create_server(server_options)

# Create the worker
aws.create_workers(WORKER_INSTANCES, worker_options)

# At this point the instances are up-and-running. To kill you must go to AWS console and kill the instances manually

