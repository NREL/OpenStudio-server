# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

unless $logger
  require 'logger'
  $logger = ::Logger.new STDOUT
  $logger.level = ::Logger::WARN
  $logger.warn 'Logger not passed in from invoking script for local.rb'
end

# Unzip an archive to a destination directory using Rubyzip gem
#
# @param archive [String] archive path for extraction
# @param dest [String] path for archived file to be extracted to
# @return [Void]
#
def unzip_archive(archive, dest)
  # Adapted from examples at...
  #  https://github.com/rubyzip/rubyzip
  #  http://seenuvasan.wordpress.com/2010/09/21/unzip-files-using-ruby/
  ::Zip::File.open(archive) do |zf|
    zf.each do |f|
      f_path = File.join(dest, f.name)
      ::FileUtils.mkdir_p(File.dirname(f_path))
      zf.extract(f, f_path) unless File.exist?(f_path) # No overwrite
    end
  end
end

# Get excel project and return analysis json and zip
#
# @param filename [String] input path and filename
# @param output_path [String] path and filename of output location, without extension
# @return [String] analysis type
#
def process_excel_project(filename, output_path)
  analyses = OpenStudio::Analysis.from_excel(filename)
  if analyses.size != 1
    $logger.error 'ERROR: EXCEL-PROJECT -- More than one seed model specified. This feature is deprecated'
    exit 1
  end
  analysis = analyses.first
  analysis.save "#{output_path}.json"
  analysis.save_zip "#{output_path}.zip"

  OpenStudio::Analysis.aws_instance_options(filename)[:analysis_type]
end

# Get batch measure project and return analysis json and zip
#
# @param filename [String] input path and filename
# @param output_path [String] path and filename of the output location, without extension
# @return [String] analysis type
#
def process_csv_project(filename, output_path)
  analysis = OpenStudio::Analysis.from_csv(filename)
  analysis.save "#{output_path}.json"
  analysis.save_zip "#{output_path}.zip"

  OpenStudio::Analysis.aws_instance_options(filename)[:analysis_type]
end

# Verify that url associated with non-aws target is alive
#
# @param target_dns [String] non-aws environment target to check the status of
# @return [String] URL of input environment target
# @todo Abstract this into a target class with access keys and such not that is referenced, not defined, here
#
def verify_target_dns(target_dns)
  # Seems like this is the only place that we are using the ServerApi--can we remove this or make the server API its
  # own gem?
  server_api = OpenStudio::Analysis::ServerApi.new(hostname: target_dns)
  unless server_api.alive?
    $logger.error "ERROR: Server at #{server_api.hostname} is not alive"
    return 1
  end
  $logger.info "Found target_dns #{target_dns} alive"
  $logger.debug "Returned target_dns status: #{server_api.machine_status}"
  target_dns
end

# Find or create the target machine
#
# @param target_type [String] environment to start /find (AWS, NREL*, vagrant)
# @param aws_instance_options [Hash] a hash defining aws options, @see #spec/schema/server_options/ex.json
# @param project_dir [String] directory of the project to save the cluster_name.json AWS connection to
# @return [String] return the server DNS
#
def find_or_create_target(target_type, aws_instance_options, project_dir)
  if target_type.casecmp('aws').zero?
    # Check or create new cluster on AWS
    cluster_folder = File.join(project_dir, 'clusters', aws_instance_options[:cluster_name])
    if ::File.exist?(File.join(cluster_folder, "#{aws_instance_options[:cluster_name]}.json"))
      puts "!!!!!!!Running Cluster!!!!!!!"
      $logger.info "It appears that a cluster for #{aws_instance_options[:cluster_name]} is already running."
      $logger.info "If this is not the case then delete ./#{aws_instance_options[:cluster_name]}.json file."
      $logger.info "Or run 'bundle exec rake clean'"
      $logger.info 'Will try to continue'

      # Load AWS instance
      aws_init_options = { credentials: { access_key_id: ::ENV['AWS_ACCESS_KEY'],
                                          secret_access_key: ::ENV['AWS_SECRET_KEY'],
                                          session_token: ::ENV['AWS_SESSION_TOKEN'],
                                          region: ::ENV['AWS_DEFAULT_REGION'] },
                           save_directory: cluster_folder }
      aws = OpenStudio::Aws::Aws.new(aws_init_options)
      aws.load_instance_info_from_file(File.join(cluster_folder, "#{aws_instance_options[:cluster_name]}.json"))
      server_dns = "http://#{aws.os_aws.server.data.dns}"
      $logger.info "Server IP address #{server_dns}"

    else
      puts "!!!!New Cluster!!!!"
      $logger.info "Creating cluster for #{aws_instance_options[:user_id]}"

      # Don't use the old API (Version 1)
      ami_version = aws_instance_options[:openstudio_server_version][0] == '2' ? 3 : 2
      aws_init_options = { credentials: { access_key_id: ::ENV['AWS_ACCESS_KEY'],
                                          secret_access_key: ::ENV['AWS_SECRET_KEY'],
                                          session_token: ::ENV['AWS_SESSION_TOKEN'],
                                          region: ::ENV['AWS_DEFAULT_REGION'] },
                           ami_lookup_version: ami_version,
                           openstudio_server_version: aws_instance_options[:openstudio_server_version],
                           save_directory: cluster_folder }
      puts "!!!!!!AWS init options:  #{aws_init_options}!!!!!!!!!"
      aws = OpenStudio::Aws::Aws.new(aws_init_options)

      server_options = {
          instance_type: aws_instance_options[:server_instance_type],
          user_id: aws_instance_options[:user_id],
          tags: aws_instance_options[:aws_tags],
      }

      worker_options = {
          instance_type: aws_instance_options[:worker_instance_type],
          user_id: aws_instance_options[:user_id],
          tags: aws_instance_options[:aws_tags]
      }

      #NRCan start
      #NRCan set ec2 instance info:
      #For CIOSB account in ca-central-1
      #nrcan_security_groups = ['sg-0d179fa0444213662']
      #nrcan_security_groups = ['sg-0c56e8aa2a535be04']
      #nrcan_subnet_id = 'subnet-096559b49eabb2323'
      #nrcan_subnet_id = 'subnet-08b0af208c5c688cf'
      #nrcan_vpc_id = 'vpc-0d262c1de89581f4b'
      #nrcan_image_id = 'ami-099df67b09ed677a3'

      # For old NRCan account in us-east-1
      #nrcan_image_id = 'ami-02283ce8cdc4a5be4'
      #nrcan_subnet_id = 'subnet-ec7518c2'
      #nrcan_vpc_id = 'vpc-7818ab02'

      # For new NRCan account in us-east-1
      nrcan_image_id = 'ami-0390ee9541b87438b'
      nrcan_subnet_id = 'subnet-01f0953dd28d10c92'
      nrcan_vpc_id = 'vpc-0b452d91d7fe83870'

      # defualt AMI for us-east-1 for OS 2.8.1:
      #nrcan_image_id = 'ami-095aa48abe1410bb2'

      # For old NRCan account in ca-central-1
      #nrcan_image_id = 'ami-02e80b6a7c06988ea'
      #nrcan_subnet_id = 'subnet-52cd6f28'
      #nrcan_vpc_id = 'vpc-e415758c'

      # For new NRCan account in ca-central-1
      #nrcan_image_id = 'ami-0b179f13161f41003'
      #nrcan_subnet_id = 'subnet-08b0af208c5c688cf'
      #nrcan_vpc_id = 'vpc-0d262c1de89581f4b'

      #server_options[:security_groups] = nrcan_security_groups
      server_options[:subnet_id] = nrcan_subnet_id
      server_options[:vpc_id] = nrcan_vpc_id
      server_options[:image_id] = nrcan_image_id

      #worker_options[:security_groups] = nrcan_security_groups
      worker_options[:subnet_id] = nrcan_subnet_id
      worker_options[:vpc_id] = nrcan_vpc_id
      worker_options[:image_id] = nrcan_image_id
      #NRCan end

      start_time = ::Time.now

      # Create the server & worker
      aws_conn_save = File.join(cluster_folder, "#{aws_instance_options[:cluster_name]}.json")
      $logger.info "Saving AWS connection information to #{aws_conn_save}"
      aws.create_server(server_options)
      aws.save_cluster_info(aws_conn_save)
      $logger.debug 'Saved AWS OS Server information. Starting worker(s)'
      aws.create_workers(aws_instance_options[:worker_node_number], worker_options)
      aws.save_cluster_info(aws_conn_save)
      $logger.debug 'Saved AWS OS Server and Worker information. Continuing'
      server_dns = "http://#{aws.os_aws.server.data.dns}"

      $logger.info "Cluster setup in #{(Time.now - start_time).round} seconds. Awaiting analyses."
      $logger.info "Server IP address is #{server_dns}"
    end
    server_dns
  else
    verify_target_dns(target_type)
  end
end