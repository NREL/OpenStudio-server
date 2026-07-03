#!/usr/bin/env ruby

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# The transport half of "something that gets the results": mirrors the results
# prefix from Nomad-accessible storage down into the local batch dir every
# --interval seconds, so the server's ExternalBatchRun ingest loop sees remote
# results as local files.
# Exits when every chunk's done marker has arrived (count from the manifest),
# after one final sync. Safe to interrupt and restart at any time.
#
# Usage:
#   ruby sync_results.rb BATCH_DIR --results-uri URI [--interval 30]
#
# Examples:
#   # For NFS/shared filesystem (results already local):
#   ruby sync_results.rb BATCH_DIR --results-uri /nfs/batch/analysis_<id>/results
#
#   # For S3/cloud storage:
#   ruby sync_results.rb BATCH_DIR --results-uri s3://my-bucket/batch/analysis_<id>/results \
#                                --aws-cmd aws --interval 30

require 'json'
require 'optparse'
require 'fileutils'

options = {
  results_uri: nil,
  interval: 30,
  aws_cmd: 'aws',
  once: false
}

opt_parser = OptionParser.new do |o|
  o.banner = 'Usage: ruby sync_results.rb BATCH_DIR --results-uri URI [options]'
  o.on('--results-uri URI', 'URI of the results directory (NFS path, S3 URI, etc.)') { |v| options[:results_uri] = v.chomp('/') }
  o.on('--interval SECONDS', Integer, 'Seconds between syncs (default 30)') { |v| options[:interval] = v }
  o.on('--aws-cmd CMD', 'AWS CLI command (default `aws`; stub for tests)') { |v| options[:aws_cmd] = v }
  o.on('--once', 'Sync once and exit (no completion wait)') { options[:once] = true }
end

opt_parser.parse!

batch_dir = ARGV.shift
abort opt_parser.banner if batch_dir.nil? || options[:results_uri].nil?
batch_dir = File.expand_path(batch_dir)

manifest_path = File.join(batch_dir, 'package', 'manifest.json')
abort "No manifest.json at #{manifest_path}" unless File.exist?(manifest_path)
num_chunks = JSON.parse(File.read(manifest_path))['chunks'].size

results_dir = File.join(batch_dir, 'results')
FileUtils.mkdir_p(results_dir)

# Determine if we're dealing with S3 or local filesystem
is_s3 = options[:results_uri].start_with?('s3://')

sync_cmd = if is_s3
  "#{options[:aws_cmd]} s3 sync --only-show-errors \"#{options[:results_uri]}\" \"#{results_dir}\""
else
  # For NFS/local filesystem, use rsync or cp
  # Using rsync for efficiency, especially when results are already mostly synced
  "rsync -a --quiet \"#{options[:results_uri]}/\" \"#{results_dir}/\""
end

def all_chunks_done?(results_dir, num_chunks)
  (0...num_chunks).all? { |i| File.exist?(File.join(results_dir, "chunk_#{i}.done")) }
end

loop do
  system(sync_cmd) || warn("sync failed (will retry): #{sync_cmd}")
  done = all_chunks_done?(results_dir, num_chunks)
  markers = (0...num_chunks).count { |i| File.exist?(File.join(results_dir, "chunk_#{i}.done")) }
  puts "[sync_results #{Time.now}] #{markers}/#{num_chunks} chunks done"
  break if options[:once] || done

  sleep options[:interval]
end

puts all_chunks_done?(results_dir, num_chunks) ? 'All chunks done; final results synced.' : 'Synced once; chunks still running.'