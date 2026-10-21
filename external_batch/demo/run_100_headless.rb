#!/usr/bin/env ruby
# Demo Run 1: Headless External Batch (100 Simulations)
# Generates 100 SEB LHS simulations, packages without server overhead,
# uploads to S3, and dispatches to AWS Batch.

require 'json'
require 'fileutils'
require 'securerandom'
require 'time'

# Load Rails environment in server/
SERVER_DIR = File.expand_path('../../server', __dir__)
require File.join(SERVER_DIR, 'config/environment')

puts "================================================================="
puts "RUN 1: HEADLESS EXTERNAL BATCH (100 SIMULATIONS)"
puts "================================================================="

t_start = Time.now

# 1. Sample 100 Datapoints
puts "\n[Step 1/3] Sampling 100 SEB LHS datapoints..."
t_sample_start = Time.now

fixture_json = File.join(SERVER_DIR, 'spec/files/SEB_LHS_2013.json')
seed_zip_path = File.join(SERVER_DIR, 'spec/files/SEB_calibration_NSGA_2013.zip')

hash = JSON.parse(File.read(fixture_json))
hash['analysis']['problem']['workflow'].each do |wf|
  (wf['variables'] || []).each { |v| v['uuid'] = SecureRandom.uuid if v['uuid'].to_s.empty? }
end
hash['analysis']['problem']['algorithm']['number_of_samples'] = 100
hash['analysis']['problem']['algorithm']['sample_method'] = 'all_variables'
hash['analysis']['problem']['algorithm']['sampling_backend'] = 'ruby'

project = Project.find_or_create_by(name: 'Demo Headless 100')
analysis = project.analyses.new(hash['analysis'])
analysis.save!
analysis.pull_out_os_variables
analysis.seed_zip = File.new(seed_zip_path)
analysis.save!

analysis.run_analysis(true, 'lhs', 'analysis_type' => 'lhs')
analysis.reload
data_points = analysis.data_points.to_a
t_sample_end = Time.now

puts "  Generated #{data_points.size} datapoints in #{(t_sample_end - t_sample_start).round(2)}s."

# 2. Package into External Batch directory
puts "\n[Step 2/3] Packaging into External Batch format (10 chunks of 10 dps)..."
t_pkg_start = Time.now
packager = ExternalBatch::Packager.new(analysis, data_points, dps_per_chunk: 10)
pkg_dir = packager.package!
batch_dir = ExternalBatch.batch_dir(analysis.id)
t_pkg_end = Time.now
puts "  Package written to: #{pkg_dir}"
puts "  Packaging time: #{(t_pkg_end - t_pkg_start).round(2)}s"

# 3. Submit directly to S3 and AWS Batch
puts "\n[Step 3/3] Uploading package to S3 and submitting AWS Batch Array Job..."
t_submit_start = Time.now

bucket = ENV['AWS_BATCH_BUCKET'] || 'osaf-batch-846898690207'
job_queue = ENV['AWS_BATCH_JOB_QUEUE'] || 'osaf-batch-queue'
job_def = ENV['AWS_BATCH_JOB_DEF'] || 'osaf-batch-runner:2'
region = 'us-east-1'

submit_script = File.expand_path('../aws/submit_batch.rb', __dir__)
cmd = "ruby \"#{submit_script}\" \"#{batch_dir}\" --bucket \"#{bucket}\" --job-queue \"#{job_queue}\" --job-definition \"#{job_def}\" --region \"#{region}\""
puts "  Executing: #{cmd}"

output = `#{cmd}`
success = $?.success?
t_submit_end = Time.now

puts output

unless success
  abort "Failed to submit batch job!"
end

detach_wall_time = (t_submit_end - t_start).round(2)

puts "\n================================================================="
puts "DEMO RUN 1 SUBMISSION SUMMARY (HEADLESS)"
puts "================================================================="
puts "  Analysis ID:             #{analysis.id}"
puts "  Datapoint Count:         100"
puts "  Chunk Count:             10 (10 array tasks)"
puts "  Sampling Time:           #{(t_sample_end - t_sample_start).round(2)}s"
puts "  Packaging Time:          #{(t_pkg_end - t_pkg_start).round(2)}s"
puts "  S3 Upload & Submit Time: #{(t_submit_end - t_submit_start).round(2)}s"
puts "  TOTAL CLIENT DETACH TIME: #{detach_wall_time}s"
puts "================================================================="
puts "Batch S3 URI: s3://#{bucket}/runs/analysis_#{analysis.id}"
puts "Local Batch Dir: #{batch_dir}"
puts "\nTo view progress in Lightweight HTML Viewer:"
puts "  Open external_batch/aws/viewer/index.html in browser and select #{batch_dir}/results"
