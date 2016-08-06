######################################################################
#  Copyright (c) 2008-2016, Alliance for Sustainable Energy.
#  All rights reserved.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

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
    raise 1
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

# Find url associated with non-aws targets
#
# @param target_type [String] non-aws environment target to get url of
# @return [String] URL of input environment target
# @todo Abstract this into a target class with access keys and such not that is referenced, not defined, here
#
def lookup_target_url(target_type)
  server_dns = nil
  case target_type.downcase
    when 'vagrant'
      server_dns = 'http://localhost:8080'
    when 'nrel24'
      server_dns = 'http://bball-130449.nrel.gov:8080'
    when 'nrel24a'
      server_dns = 'http://bball-130553.nrel.gov:8080'
    when 'nrel24b'
      server_dns = 'http://bball-130590.nrel.gov:8080'
    else
      return target_type if target_type.include? 'http'
      puts "ERROR: TARGET -- Unknown 'target_type' in #{__method__}"
      raise 1
  end
  server_dns
end

# Parse the AWS credentials YAML file and set the appropriate environment variables
#
# @param aws_yml_path [String] path to the AWS credentials file
# @return [Void]
#
def parse_aws_yml(aws_yml_path)
  # Unset any AWS environment variables
  if ::ENV.key? 'AWS_ACCESS_KEY'
    ::ENV.delete 'AWS_ACCESS_KEY'
    $logger.info 'Removed AWS_ACCESS_KEY from the environment'
  end
  if ::ENV.key? 'AWS_SECRET_KEY'
    ::ENV.delete 'AWS_SECRET_KEY'
    $logger.info 'Removed AWS_SECRET_KEY from the environment'
  end
  if ::ENV.key? 'AWS_DEFAULT_REGION'
    ::ENV.delete 'AWS_DEFAULT_REGION'
    $logger.info 'Removed AWS_DEFAULT_REGION from the environment'
  end

  # Load in the credentials and validate that the required fields are present
  aws_credentials = ::YAML.load_file(aws_yml_path)
  unless aws_credentials.keys.include? 'access_key_id'
    $logger.error "No access key provided in #{aws_yml_path}. An example: 'access_key_id: ABC...'"
    raise 1
  end
  unless aws_credentials.keys.include? 'secret_access_key'
    $logger.error "No secret key provided in #{aws_yml_path}. An example: 'secret_access_key: ABC...'"
    raise 1
  end
  unless aws_credentials.keys.include? 'region'
    $logger.error "No access key provided in #{aws_yml_path}. An example: 'region: us-east-1'"
    raise 1
  end

  # Set the AWS environment variables
  ::ENV['AWS_ACCESS_KEY'] = aws_credentials['access_key_id']
  ::ENV['AWS_SECRET_KEY'] = aws_credentials['secret_access_key']
  ::ENV['AWS_DEFAULT_REGION'] = aws_credentials['region']
  $logger.info 'Set new AWS environment variables using the credentials file'
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
    if ::File.exist?("#{aws_instance_options[:cluster_name]}.json")
      $logger.info "It appears that a cluster for #{aws_instance_options[:cluster_name]} is already running."
      $logger.info "If this is not the case then delete ./#{aws_instance_options[:cluster_name]}.json file."
      $logger.info "Or run 'bundle exec rake clean'"
      $logger.info 'Will try to continue'

      # Load AWS instance
      aws_init_options = { credentials: { access_key_id: ::ENV['AWS_ACCESS_KEY'],
                                          secret_access_key: ::ENV['AWS_SECRET_KEY'], region: ::ENV['AWS_DEFAULT_REGION'] } }
      aws = OpenStudio::Aws::Aws.new(aws_init_options)
      aws.load_instance_info_from_file("#{aws_instance_options[:cluster_name]}.json")
      server_dns = "http://#{aws.os_aws.server.data.dns}"
      $logger.info "Server IP address #{server_dns}"

    else
      $logger.info "Creating cluster for #{aws_instance_options[:user_id]}"

      # Don't use the old API (Version 1)
      aws_init_options = { credentials: { access_key_id: ::ENV['AWS_ACCESS_KEY'],
                                          secret_access_key: ::ENV['AWS_SECRET_KEY'], region: ::ENV['AWS_DEFAULT_REGION'] } }
      aws = OpenStudio::Aws::Aws.new(aws_init_options)

      server_options = {
        instance_type: aws_instance_options[:server_instance_type],
        user_id: aws_instance_options[:user_id],
        tags: aws_instance_options[:aws_tags]
      }

      worker_options = {
        instance_type: aws_instance_options[:worker_instance_type],
        user_id: aws_instance_options[:user_id],
        tags: aws_instance_options[:aws_tags]
      }

      start_time = ::Time.now

      # Create the server & worker
      aws_conn_save = ::File.join(project_dir, "#{aws_instance_options[:cluster_name]}.json")
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
    lookup_target_url(target_type)
  end
end
