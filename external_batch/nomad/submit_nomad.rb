#!/usr/bin/env ruby

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Control-plane helper: pushes a packaged batch dir to a shared location (NFS or S3)
# and submits a Nomad job (one task per chunk). Plain Ruby driving the Nomad CLI —
# credentials come from the standard Nomad CLI chain (env vars, etc.).
# Data never flows through this script; only the manifest is read locally.
#
# Usage:
#   ruby submit_nomad.rb BATCH_DIR --nomad-addr http://nomad:4646 --job-template external_batch/nomad/templates/job_array.hcl --package-location /nfs/batch
#   ruby submit_nomad.rb BATCH_DIR --nomad-addr http://nomad:4646 --job-template external_batch/nomad/templates/job_array.hcl --package-location s3://my-bucket/batch
#
# After submitting, the server's ingest loop can see the results as they land
# (if using shared filesystem) or a separate sync process is needed (if using S3).

require 'json'
require 'net/http'
require 'optparse'
require 'fileutils'
require 'tempfile'
require 'uri'

options = {
  nomad_addr: 'http://localhost:4646',
  job_template: nil,
  package_location: nil,
  job_name: nil,
  namespace: 'default',
  ssh_host: nil,
  ssh_key: nil,
  dry_run: false
}

opt_parser = OptionParser.new do |o|
  o.banner = 'Usage: ruby submit_nomad.rb BATCH_DIR [options]'
  o.on('--nomad-addr ADDRESS', "Nomad server address (default: #{options[:nomad_addr]})") { |v| options[:nomad_addr] = v }
  o.on('--job-template PATH', 'Path to Nomad job template file (required)') { |v| options[:job_template] = v }
  o.on('--package-location LOCATION', 'Base location for packages and results (NFS path or S3 URI)') { |v| options[:package_location] = v }
  o.on('--job-name NAME', 'Job name (default osaf-nomad-analysis-<id>)') { |v| options[:job_name] = v }
  o.on('--namespace NAMESPACE', 'Nomad namespace (default: "default")') { |v| options[:namespace] = v }
  o.on('--ssh-host HOST', 'SSH host for rsync (e.g., ubuntu@<NOMAD_SERVER_FLOATING_IP>)') { |v| options[:ssh_host] = v }
  o.on('--ssh-key PATH', 'SSH key path for rsync (default: /config/ssh/id_rsync)') { |v| options[:ssh_key] = v }
  o.on('--dry-run', 'Print the commands without executing them') { options[:dry_run] = true }
end

opt_parser.parse!

batch_dir = ARGV.shift
abort opt_parser.banner if batch_dir.nil?
batch_dir = File.expand_path(batch_dir)

manifest_path = File.join(batch_dir, 'package', 'manifest.json')
abort "No manifest.json at #{manifest_path} — package the analysis first" unless File.exist?(manifest_path)
manifest = JSON.parse(File.read(manifest_path))
analysis_id = manifest['analysis_id']
num_chunks = manifest['chunks'].size

# Determine package and results URIs based on package_location
package_location = options[:package_location]
if package_location.match?(/^s3:\/\//)
  package_type = 's3'
  package_uri = "#{package_location.chomp('/')}/analysis_#{analysis_id}/package"
  results_uri = "#{package_location.chomp('/')}/analysis_#{analysis_id}/results"
else
  package_type = 'nfsmount'
  package_uri = File.join(package_location, "analysis_#{analysis_id}", "package")
  results_uri = File.join(package_location, "analysis_#{analysis_id}", "results")
end

  # Ensure the package is available at the package_uri
  source_package = File.join(batch_dir, 'package')
  if package_type == 's3'
    # Sync the package directory to S3
    sync_cmd = "aws s3 sync --only-show-errors --delete \"#{source_package}\" \"#{package_uri}\""
    puts "+ #{sync_cmd}"
    unless options[:dry_run]
      system(sync_cmd) || abort("Command failed: #{sync_cmd}")
    end
  elsif package_type == 'nfsmount'
    if options[:ssh_host]
      remote_dir = package_uri
      ssh_key_arg = options[:ssh_key] ? "-i #{options[:ssh_key]}" : ''
      copy_cmd = "rsync -avz --delete -e \"ssh #{ssh_key_arg} -o StrictHostKeyChecking=no\" \"#{source_package}/\" \"#{options[:ssh_host]}:#{remote_dir}/\""
      puts "+ #{copy_cmd}"
      unless options[:dry_run]
        system(copy_cmd) || abort("rsync to NFS via SSH failed: #{copy_cmd}")
        puts "Package synced to #{options[:ssh_host]}:#{remote_dir}/"
      end
    else
      unless File.expand_path(source_package) == File.expand_path(package_uri)
        FileUtils.mkdir_p(File.dirname(package_uri))
        copy_cmd = "cp -r \"#{source_package}\" \"#{package_uri}\""
        puts "+ #{copy_cmd}"
        unless options[:dry_run]
          FileUtils.rm_rf(package_uri) if File.exist?(package_uri)
          FileUtils.cp_r(source_package, package_uri)
        end
      end
    end
  else
    abort "Unsupported package type: #{package_type}"
  end

# Read the job template and replace placeholders
template_content = File.read(options[:job_template])
job_name = options[:job_name] || "osaf-nomad-analysis-#{analysis_id}"
rendered_job = template_content
  .gsub('{{ANALYSIS_ID}}', analysis_id.to_s)
  .gsub('{{NUM_CHUNKS}}', num_chunks.to_s)
  .gsub('{{JOB_NAME}}', job_name)
  .gsub('{{NAMESPACE}}', options[:namespace])
  .gsub('{{PACKAGE_URI}}', package_uri)
  .gsub('{{RESULTS_URI}}', results_uri)

# Submit job via Nomad HTTP API
unless options[:dry_run]
  nomad_addr = options[:nomad_addr] || 'http://localhost:4646'
  uri = URI.parse("#{nomad_addr.chomp('/')}/v1/jobs")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 10
  http.read_timeout = 30
  
  # Step 1: Parse HCL to JSON via /v1/jobs/parse (Nomad v1.5.x doesn't support JobHCL directly on /v1/jobs)
  parse_uri = URI.parse("#{nomad_addr.chomp('/')}/v1/jobs/parse")
  parse_payload = JSON.generate({ JobHCL: rendered_job })
  
  parse_request = Net::HTTP::Post.new(parse_uri.request_uri)
  parse_request.body = parse_payload
  parse_request['Content-Type'] = 'application/json'
  
  puts "* POST #{parse_uri} (parse HCL template)"
  parse_response = http.request(parse_request)
  
  abort "Nomad parse error: #{parse_response.code} #{parse_response.message}\n#{parse_response.body}" unless parse_response.code.to_i == 200
  
  job_json = JSON.parse(parse_response.body)
  
  # Step 2: Submit parsed JSON job to /v1/jobs
  submit_payload = JSON.generate({ Job: job_json })
  
  request = Net::HTTP::Post.new(uri.request_uri)
  request.body = submit_payload
  request['Content-Type'] = 'application/json'
  
  puts "+ POST #{uri} (job: #{job_name}, #{num_chunks} chunk(s))"
  response = http.request(request)
  
  abort "Nomad API error: #{response.code} #{response.message}\n#{response.body}" unless response.code.to_i == 200
  
  result = JSON.parse(response.body)
  job_id = job_json['ID'] || job_json['Name'] || result['EvalID']
  abort 'Failed to determine job ID from Nomad response' unless job_id
  
  puts "Submitted #{num_chunks} chunk(s) for analysis #{analysis_id}: jobID=#{job_id} evalID=#{result['EvalID']}"
else
  puts "+ POST (dry-run) #{options[:nomad_addr] || 'http://localhost:4646'}/v1/jobs"
  puts "  Job: #{job_name}, #{num_chunks} chunk(s)"
end

puts
puts 'Results will be available at:'
puts "  #{results_uri}"
puts
puts 'If using S3, ensure results are synced back to the server\'s results directory.'
