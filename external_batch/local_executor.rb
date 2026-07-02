#!/usr/bin/env ruby

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# LOCAL/MOCK executor for external batch packages. Stands in for Kestrel
# (SLURM array + Apptainer) or AWS Batch (array job): each chunk in the
# manifest becomes one run_chunk.rb subprocess, capped at --parallel concurrent
# processes — exactly the shape of an array job, minus the scheduler. Point
# --openstudio at a real OpenStudio CLI for true simulations, or at a stub for
# contract tests.
#
# Usage:
#   ruby external_batch/local_executor.rb <batch_dir> [--openstudio CMD] [--parallel N]
#
# <batch_dir> is <external_batch_root>/analysis_<id> (contains package/ and results/).

require 'json'
require 'fileutils'
require 'optparse'
require 'rbconfig'

options = {
  openstudio: ENV['OPENSTUDIO_EXE_PATH'] || 'openstudio',
  parallel: 1,
  runner: File.expand_path(File.join(__dir__, 'runner', 'run_chunk.rb'))
}
opt_parser = OptionParser.new do |o|
  o.banner = 'Usage: ruby local_executor.rb BATCH_DIR [options]'
  o.on('--openstudio CMD', 'OpenStudio CLI command or path') { |v| options[:openstudio] = v }
  o.on('--parallel N', Integer, 'Concurrent chunk processes (default 1)') { |v| options[:parallel] = v }
  o.on('--runner PATH', 'Path to run_chunk.rb') { |v| options[:runner] = File.expand_path(v) }
end
opt_parser.parse!

batch_dir = ARGV.shift
abort opt_parser.banner if batch_dir.nil?
batch_dir = File.expand_path(batch_dir)

package_dir = File.join(batch_dir, 'package')
results_dir = File.join(batch_dir, 'results')
manifest_path = File.join(package_dir, 'manifest.json')
abort "No manifest.json at #{manifest_path}" unless File.exist?(manifest_path)

manifest = JSON.parse(File.read(manifest_path))
num_chunks = manifest['chunks'].size
parallel = [options[:parallel], 1].max

# a synced/remote copy of the batch dir may not have results/ yet (S3 has no empty dirs)
FileUtils.mkdir_p results_dir

puts "Executing #{num_chunks} chunk(s) for analysis #{manifest['analysis_id']} (#{manifest['data_point_count']} datapoints, parallel=#{parallel})"

ruby = RbConfig.ruby
statuses = {}
running = {}
queue = (0...num_chunks).to_a

until queue.empty? && running.empty?
  while running.size < parallel && !queue.empty?
    ci = queue.shift
    cmd = [ruby, options[:runner],
           '--package', package_dir,
           '--results', results_dir,
           '--chunk', ci.to_s,
           '--openstudio', options[:openstudio]]
    log_path = File.join(results_dir, "chunk_#{ci}.log")
    puts "Starting chunk #{ci} (log: #{log_path})"
    pid = Process.spawn(*cmd, [:out, :err] => [log_path, 'w'])
    running[pid] = ci
  end

  pid = Process.wait
  ci = running.delete(pid)
  statuses[ci] = $?.exitstatus
  puts "Chunk #{ci} exited with #{statuses[ci]}"
end

failed = statuses.select { |_, code| code != 0 }
if failed.empty?
  puts 'All chunks completed'
else
  warn "Chunks failed: #{failed.keys.sort.join(', ')}"
  exit 1
end
