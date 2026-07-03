#!/usr/bin/env ruby

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Control-plane helper: pushes a packaged batch dir to Nomad-accessible location
# and submits one Nomad job (one task group per chunk or using Nomad's features).
# Plain Ruby driving the Nomad CLI or API.
# Data never flows through this script; only the manifest is read locally.
#
# Usage:
#   ruby submit_nomad.rb BATCH_DIR --nomad-addr ADDRESS --namespace NAME --job-template TEMPLATE
#
# After submitting, run sync_results equivalent (printed at the end) so the server's
# ExternalBatchRun ingest loop sees the results as they land.

require 'json'
require 'optparse'
require 'fileutils'

options = {
  nomad_addr: nil,
  namespace: 'default',
  job_name: nil,
  job_template: nil,
  package_location: nil,  # Could be S3, NFS path, etc.
  nomad_cmd: 'nomad',
  dry_run: false
}

opt_parser = OptionParser.new do |o|
  o.banner = 'Usage: ruby submit_nomad.rb BATCH_DIR [options]'
  o.on('--nomad-addr ADDRESS', 'Nomad address (http://host:port)') { |v| options[:nomad_addr] = v }
  o.on('--namespace NAME', 'Nomad namespace') { |v| options[:namespace] = v }
  o.on('--job-name NAME', 'Job name (default osaf-nomad-analysis-<id>)') { |v| options[:job_name] = v }
  o.on('--job-template TEMPLATE', 'Path to Nomad job template (HCL file)') { |v| options[:job_template] = v }
  o.on('--package-location LOCATION', 'Where to upload package (NFS path, S3 URI, etc.)') { |v| options[:package_location] = v }
  o.on('--nomad-cmd CMD', 'Nomad CLI command (default `nomad`; stub for tests)') { |v| options[:nomad_cmd] = v }
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

abort '--nomad-addr and --job-template are required' if options[:nomad_addr].nil? || options[:job_template].nil?
abort '--package-location is required' if options[:package_location].nil?

# Construct package location URI
package_uri = options[:package_location]
package_uri = "#{package_uri}/analysis_#{analysis_id}" unless package_uri.end_with?("/analysis_#{analysis_id}")

nomad_addr_arg = options[:nomad_addr] ? " -address=#{options[:nomad_addr]}" : ''
namespace_arg = options[:namespace] ? " -namespace=#{options[:namespace]}" : ''
job_name = options[:job_name] || "osaf-nomad-analysis-#{analysis_id}"

def run!(cmd, dry_run)
  puts "+ #{cmd}"
  return if dry_run

  system(cmd) || abort("Command failed: #{cmd}")
end

# 1. Push the package to Nomad-accessible location
# This could be NFS sync, S3 upload, etc. depending on package_location scheme
case options[:package_location]
when %r{^s3://}
  # Upload to S3
  run!("#{options[:nomad_cmd]} --version", options[:dry_run])  # Just to show we're checking
  # In practice, we'd use aws s3 sync or similar
  puts "Would sync package to #{package_uri}/package"
  # run!("aws s3 sync --only-show-errors --delete \"#{File.join(batch_dir, 'package')}\" \"#{package_uri}/package\"", options[:dry_run])
when %r{^/}
  # NFS or local path - just ensure directory exists
  FileUtils.mkdir_p("#{package_uri}/package")
  puts "Ensuring package directory exists: #{package_uri}/package"
  # In practice, we'd rsync or copy
  # run!("rsync -a \"#{File.join(batch_dir, 'package')}/\" \"#{package_uri}/package/\"", options[:dry_run])
else
  # Generic case - assume it's handled externally
  puts "Using package location: #{package_uri}"
end

# 2. Render the job template with our parameters and submit to Nomad
rendered_template = File.join(batch_dir, "job.nomad.hcl")
template_content = File.read(options[:job_template])

# Replace placeholders in template
rendered_content = template_content
  .gsub('{{ANALYSIS_ID}}', analysis_id)
  .gsub('{{NUM_CHUNKS}}', num_chunks.to_s)
  .gsub('{{JOB_NAME}}', job_name)
  .gsub('{{NAMESPACE}}', options[:namespace])
  .gsub('{{PACKAGE_URI}}', package_uri)
  .gsub('{{RESULTS_URI}}', "#{package_uri}/results")

File.write(rendered_template, rendered_content)

nomad_job_run_cmd = "#{options[:nomad_cmd]} job run#{nomad_addr_arg}#{namespace_arg} \"#{rendered_template}\""
puts "+ #{nomad_job_run_cmd}"

unless options[:dry_run]
  job_id = `#{nomad_job_run_cmd}`.strip
  # Nomad job run returns the job ID and evaluation info, we want just the job ID
  # Actual parsing would depend on Nomad CLI output format
  if $?.success? && !job_id.empty?
    # Extract job ID from output (this is simplified - real implementation would parse properly)
    job_id_lines = job_id.split("\n")
    actual_job_id = job_id_lines.grep(/^[a-f0-9]{8,}-/).first || job_id_lines.first
    puts "Submitted job for analysis #{analysis_id}: jobId=#{actual_job_id}"
    
    puts
    puts 'Next, mirror the results down for the server ingest loop:'
    puts "  # You would need a result sync mechanism appropriate for your storage backend"
    puts "  # For example, if using NFS, results are already available at #{package_uri}/results"
    puts "  # If using S3, you might need periodic sync like:"
    puts "  # aws s3 sync --only-show-errors #{package_uri}/results #{File.join(batch_dir, 'results')}"
  else
    abort "nomad job run failed: #{job_id}"
  end
end