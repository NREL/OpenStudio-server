# This script is used to test the result of the create_vms.rb script for AWS. 
# It reads the test_amis.json script that is the result of the create_vms and
# calls the instances.  

# The format of the JSON file that defines the AMI's is the same as the 
# format used on developer.nrel.gov/.../amis.json.  It is in the format of
#    {
#        "1.2.0" : {
#        "server" : "ami-29e5cd40",
#        "worker": "ami-a9e4ccc0",
#        "cc2worker": "ami-5be4cc32"
#      }
#    }


# create the cloud instance


formulation_file = "./SimpleContinuousExample/analysis.json"
analysis_zip_file = "./SimpleContinuousExample/analysis.zip"

# TODO: configure this with bundler 

require 'openstudio-analysis' # Need to install openstudio-analysis gem
require 'openstudio-aws'


aws = OpenStudio::Aws::Aws.new()
#server_options = {instance_type: "m1.small"}  # 1 core ($0.06/hour)
server_options = {instance_type: "m2.xlarge"} # 2 cores ($0.410/hour)

#worker_options = {instance_type: "m1.small"} # 1 core ($0.06/hour)
#worker_options = {instance_type: "m2.xlarge" } # 2 cores ($0.410/hour)
#worker_options = {instance_type: "m2.2xlarge" } # 4 cores ($0.820/hour)
#worker_options = {instance_type: "m2.4xlarge" } # 8 cores ($1.64/hour) 
worker_options = {instance_type: "cc2.8xlarge"} # 16 cores ($2.40/hour) | we turn off hyperthreading

# Create the server
aws.create_server(server_options)

# Create the worker
aws.create_workers(NUMBER_OF_WORKERS, worker_options)
