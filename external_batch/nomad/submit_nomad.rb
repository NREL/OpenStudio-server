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
require 'optparse'
require 'fileutils'
require 'tempfile'

options = {
  nomad_addr: nil,
  nomad_cmd: 'nomad',
  job_template: nil,
  package_location: nil,
  job_name: nil,
  namespace: 'default',
  dry_run: false
}

opt_parser = OptionParser.new do |o|
  o.banner = 'Usage: ruby submit_nomad.rb BATCH_DIR [options]'
  o.on('--nomad-addr ADDRESS', 'Nomad server address (e.g., http://localhost:4646)') { |v| options[:nomad_addr] = v }
  o.on('--nomad-cmd CMD', 'Nomad CLI command (default `nomad`; stub for tests)') { |v| options[:nomad_cmd] = v }
  o.on('--job-template PATH', 'Path to Nomad job template file (required)') { |v| options[:job_template] = v }
  o.on('--package-location LOCATION', 'Base location for packages and results (NFS path or S3 URI)') { |v| options[:package_location] = v }
  o.on('--job-name NAME', 'Job name (default osaf-nomad-analysis-<id>)') { |v| options[:job_name] = v }
  o.on('--namespace NAMESPACE', 'Nomad namespace (default: "default")') { |v| options[:namespace] = v }
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

abort '--job-template and --package-location are required' if options[:job_template].nil? || options[:package_location].nil?
abort "Job template file not found: #{options[:job_template]}" unless File.exist?(options[:job_template])

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
if package_type == 's3'
  # Sync the package directory to S3
  sync_cmd = "aws s3 sync --only-show-errors --delete \"#{File.join(batch_dir, 'package')}\" \"#{package_uri}\""
  puts "+ #{sync_cmd}"
  unless options[:dry_run]
    system(sync_cmd) || abort("Command failed: #{sync_cmd}")
  end
elsif package_type == 'nfsmount'
  # Ensure the destination directory exists and copy the package
  FileUtils.mkdir_p(File.dirname(package_uri))
  copy_cmd = "cp -r \"#{File.join(batch_dir, 'package')}\" \"#{package_uri}\""
  puts "+ #{copy_cmd}"
  unless options[:dry_run]
    FileUtils.rm_rf(package_uri) if File.exist?(package_uri)
    FileUtils.cp_r(File.join(batch_dir, 'package'), package_uri)
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

# Write the rendered job to a temporary file
temp_job_file = Tempfile.new(['nomad_job', '.hcl'])
begin
  temp_job_file.write(rendered_job)
  temp_job_file.flush

  # Run nomad job run with JSON output to get the job ID
  nomad_addr_arg = options[:nomad_addr] ? " -address=#{options[:nomad_addr]}" : ''
  run_cmd = "#{options[:nomad_cmd]}#{nomad_addr_arg} job run -output=json #{temp_job_file.path}"
  puts "+ #{run_cmd}"
  unless options[:dry_run]
    output = `#{run_cmd}`
    abort "nomad job run failed: #{$?.exitstatus}" unless $?.success?
    begin
      json_output = JSON.parse(output)
      job_id = json_output['job']['ID']
      abort 'Failed to parse job ID from Nomad response' unless job_id
      puts "Submitted #{num_chunks} chunk(s) for analysis #{analysis_id}: jobID=#{job_id}"
    rescue JSON::ParserError => e
      abort "Failed to parse Nomad job run output as JSON: #{e.message}\nOutput: #{output}"
    end
  end
ensure
  temp_job_file.close
  temp_job_file.unlink
end

puts
puts 'Results will be available at:'
puts "  #{results_uri}"
puts
puts 'If using S3, ensure results are synced back to the server\'s results directory.'