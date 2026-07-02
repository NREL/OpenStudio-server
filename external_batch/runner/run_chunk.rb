#!/usr/bin/env ruby

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# External batch RUNNER: executes one chunk of a packaged analysis with the
# OpenStudio CLI and writes per-datapoint results directories. Pure stdlib —
# no Rails, no gems, no server/DB access — so the very same file runs:
#   - locally (mock executor / dev / CI), driven by local_executor.rb
#   - on Kestrel inside an Apptainer image as a SLURM array task
#   - on AWS Batch inside the nrel/openstudio docker image as an array job
#
# Chunk index resolution: --chunk N, else SLURM_ARRAY_TASK_ID, else
# AWS_BATCH_JOB_ARRAY_INDEX, else ALL chunks are run sequentially.
#
# Results contract (consumed by ExternalBatch::Ingester server-side):
#   <results>/<dp_id>/
#     status.json            written LAST (its presence marks the dp ingestable)
#     run.log, measure_attributes.json, objectives.json, out.osw, in.osm,
#     data_point.zip, reports/*, dp.log, initialize.log, finalize.log,
#     datapoint_final.log, oscli_simulation.log
#   <results>/chunk_<i>.done  written when the chunk finishes

require 'json'
require 'fileutils'
require 'optparse'
require 'timeout'
require 'socket'
require 'time'
require 'rbconfig'

SCHEMA_VERSION = 1

# keep in sync with server/app/lib/utility/oss.rb ENV_VARS_TO_UNSET_FOR_OSCLI
ENV_VARS_TO_UNSET_FOR_OSCLI = [
  'BUNDLE_GEMFILE',
  'BUNDLE_PATH',
  'RUBYLIB',
  'RUBYOPT',
  'BUNDLE_BIN_PATH',
  'BUNDLER_VERSION',
  'BUNDLER_ORIG_PATH',
  'BUNDLER_ORIG_MANPATH',
  'GEM_PATH',
  'GEM_HOME',
  'BUNDLER_SETUP'
].freeze

options = {
  package: nil,
  results: nil,
  chunk: nil,
  openstudio: ENV['OPENSTUDIO_EXE_PATH'] || 'openstudio'
}
OptionParser.new do |o|
  o.banner = 'Usage: ruby run_chunk.rb --package DIR --results DIR [options]'
  o.on('--package DIR', 'Package directory (contains manifest.json)') { |v| options[:package] = File.expand_path(v) }
  o.on('--results DIR', 'Results directory to write to') { |v| options[:results] = File.expand_path(v) }
  o.on('--chunk N', Integer, 'Chunk index to run (default: SLURM_ARRAY_TASK_ID, AWS_BATCH_JOB_ARRAY_INDEX, or all)') { |v| options[:chunk] = v }
  o.on('--openstudio CMD', 'OpenStudio CLI command or path (default: OPENSTUDIO_EXE_PATH env or `openstudio`)') { |v| options[:openstudio] = v }
end.parse!

abort '--package and --results are required' if options[:package].nil? || options[:results].nil?

manifest_path = File.join(options[:package], 'manifest.json')
abort "No manifest.json found at #{manifest_path}" unless File.exist?(manifest_path)
manifest = JSON.parse(File.read(manifest_path))
if manifest['schema_version'] != SCHEMA_VERSION
  abort "Manifest schema_version #{manifest['schema_version']} does not match runner schema_version #{SCHEMA_VERSION}"
end

analysis_dir = File.join(options[:package], "analysis_#{manifest['analysis_id']}")
abort "No analysis directory found at #{analysis_dir}" unless Dir.exist?(analysis_dir)

chunk_index = options[:chunk]
chunk_index ||= ENV['SLURM_ARRAY_TASK_ID']&.to_i
chunk_index ||= ENV['AWS_BATCH_JOB_ARRAY_INDEX']&.to_i
chunk_indices = chunk_index.nil? ? (0...manifest['chunks'].size).to_a : [chunk_index]

FileUtils.mkdir_p options[:results]

def log(msg)
  puts "[run_chunk #{Time.now.iso8601}] #{msg}"
  $stdout.flush
end

# POSIX: run children in their own process group so a timeout can kill the
# whole tree (shell, OSCLI, EnergyPlus). Windows uses taskkill /T instead.
def spawn_pgroup_opts
  Gem.win_platform? ? {} : { pgroup: true }
end

# Replicates the dp-level script hooks from DjJobs::RunSimulateDataPoint#run_script_with_args.
# POSIX-only; on Windows (mock executor) scripts are skipped with a warning.
def run_data_point_script(analysis_dir, analysis_id, dp_id, script_name, results_dp_dir, runner_log)
  pid = nil
  script_path = File.join(analysis_dir, 'scripts', 'data_point', "#{script_name}.sh")
  return unless File.file?(script_path)

  if Gem.win_platform?
    runner_log.puts "WARNING: #{script_name}.sh present but shell scripts are not supported on Windows; skipping"
    return
  end

  args_path = File.join(analysis_dir, 'scripts', 'data_point', "#{script_name}.args")
  args = []
  if File.file?(args_path)
    parsed = JSON.parse(File.read(args_path))
    args = parsed if parsed.is_a?(Array)
  end

  File.chmod(0o755, script_path)
  text = File.read(script_path)
  File.open(script_path, 'wb') { |f| f.print text.gsub(/\r\n/m, "\n") }

  log_path = File.join(results_dp_dir, "#{script_name}.log")
  env = { 'SCRIPT_ANALYSIS_ID' => analysis_id, 'SCRIPT_DATA_POINT_ID' => dp_id }
  pid = Process.spawn(env, script_path, *args.map(&:to_s), [:out, :err] => [log_path, 'w'], **spawn_pgroup_opts)
  Timeout.timeout(4 * 3600) { Process.wait(pid) }
  runner_log.puts "#{script_name}.sh exited with #{$?.exitstatus}"
rescue Timeout::Error
  kill_process_tree(pid, runner_log) if pid
  runner_log.puts "#{script_name}.sh killed after 4h timeout"
rescue StandardError => e
  runner_log.puts "#{script_name}.sh failed: #{e.message}"
end

def kill_process_tree(pid, runner_log)
  if Gem.win_platform?
    system("taskkill /pid #{pid} /f /T >NUL 2>&1")
  else
    child_pid = `ps -o pid= --ppid "#{pid}"`.to_i
    Process.kill('KILL', child_pid) if child_pid > 0
    Process.kill('KILL', pid)
  end
rescue StandardError => e
  runner_log.puts "Error killing process #{pid}: #{e.message}"
end

def copy_if_exists(src, dest_dir, dest_name = nil)
  return unless File.exist?(src)

  FileUtils.mkdir_p dest_dir
  FileUtils.cp src, File.join(dest_dir, dest_name || File.basename(src))
end

def run_data_point(dp_id, analysis_dir, results_root, manifest, openstudio_cmd)
  started_at = Time.now.iso8601
  dp_dir = File.join(analysis_dir, "data_point_#{dp_id}")
  osw_path = File.join(dp_dir, 'data_point.osw')
  run_dir = File.join(dp_dir, 'run')

  results_dp = File.join(results_root, dp_id)
  tmp_results_dp = File.join(results_root, ".#{dp_id}.tmp")
  FileUtils.rm_rf tmp_results_dp
  FileUtils.mkdir_p tmp_results_dp

  completed_status = 'Fail'
  exit_status = nil
  runner_log_path = File.join(tmp_results_dp, 'dp.log')

  File.open(runner_log_path, 'w') do |runner_log|
    runner_log.sync = true
    runner_log.puts "Running datapoint #{dp_id} on #{Socket.gethostname} at #{started_at}"

    unless File.exist?(osw_path)
      runner_log.puts "ERROR: missing #{osw_path}"
      break
    end

    run_data_point_script(analysis_dir, manifest['analysis_id'], dp_id, 'initialize', tmp_results_dp, runner_log)

    # mirror the worker's OSCLI invocation (DjJobs::RunSimulateDataPoint#perform)
    cli_verbose = manifest['cli_verbose'] || ''
    cli_debug = manifest['cli_debug'] || ''
    cmd = "#{openstudio_cmd} #{cli_verbose} run --workflow \"#{osw_path}\" #{cli_debug}".squeeze(' ').strip
    process_log = File.join(dp_dir, 'oscli_simulation.log')
    runner_log.puts "Running workflow using cmd #{cmd} and writing log to #{process_log}"

    oscli_env_unset = ENV_VARS_TO_UNSET_FOR_OSCLI.map { |x| [x, nil] }.to_h
    timeout_s = manifest['run_workflow_timeout'].to_i
    timeout_s = 28_800 unless timeout_s.positive?

    begin
      pid = Process.spawn(oscli_env_unset, cmd, [:err, :out] => [process_log, 'w'], **spawn_pgroup_opts)
      Timeout.timeout(timeout_s) { Process.wait(pid) }
      exit_status = $?.exitstatus
      runner_log.puts "OSCLI exited with #{exit_status}"
    rescue Timeout::Error
      runner_log.puts "Killing process for #{osw_path} due to timeout after #{timeout_s}s"
      kill_process_tree(pid, runner_log)
      exit_status = nil
    rescue StandardError => e
      runner_log.puts "Workflow #{osw_path} failed with error #{e.message}"
    end

    out_osw_path = File.join(dp_dir, 'out.osw')
    if exit_status == 0 && File.exist?(out_osw_path)
      begin
        completed_status = JSON.parse(File.read(out_osw_path))['completed_status'] || 'Fail'
      rescue JSON::ParserError => e
        runner_log.puts "Could not parse out.osw: #{e.message}"
      end
    end

    run_data_point_script(analysis_dir, manifest['analysis_id'], dp_id, 'finalize', tmp_results_dp, runner_log)

    # collect the results contract, honoring the analysis download_* flags
    copy_if_exists(File.join(run_dir, 'run.log'), tmp_results_dp)
    copy_if_exists(File.join(run_dir, 'measure_attributes.json'), tmp_results_dp)
    copy_if_exists(File.join(run_dir, 'objectives.json'), tmp_results_dp)
    copy_if_exists(File.join(run_dir, 'datapoint_final.log'), tmp_results_dp)
    copy_if_exists(process_log, tmp_results_dp)
    copy_if_exists(out_osw_path, tmp_results_dp) if manifest['download_osw'] || completed_status == 'Fail'
    copy_if_exists(File.join(run_dir, 'in.osm'), tmp_results_dp) if manifest['download_osm']
    copy_if_exists(File.join(run_dir, 'data_point.zip'), tmp_results_dp) if manifest['download_zip'] || completed_status == 'Fail'
    if manifest['download_reports']
      Dir[File.join(dp_dir, 'reports', '*.{html,json,csv,xml,mat}')].each do |rep|
        copy_if_exists(rep, File.join(tmp_results_dp, 'reports'))
      end
    end

    runner_log.puts "Finished datapoint #{dp_id} with completed_status #{completed_status}"
  end

  status = {
    'schema_version' => SCHEMA_VERSION,
    'analysis_id' => manifest['analysis_id'],
    'data_point_id' => dp_id,
    'completed_status' => completed_status,
    'exit_status' => exit_status,
    'started_at' => started_at,
    'completed_at' => Time.now.iso8601,
    'hostname' => Socket.gethostname
  }

  # rename into place, then write status.json LAST — the ingester only picks up
  # directories that contain status.json
  FileUtils.rm_rf results_dp
  FileUtils.mv tmp_results_dp, results_dp
  File.write(File.join(results_dp, 'status.json'), JSON.pretty_generate(status))

  completed_status
end

overall_failures = 0
chunk_indices.each do |ci|
  dp_ids = manifest['chunks'][ci]
  abort "Chunk index #{ci} out of range (#{manifest['chunks'].size} chunks)" if dp_ids.nil?

  log "Running chunk #{ci} with #{dp_ids.size} datapoints"
  dp_ids.each do |dp_id|
    status = begin
      run_data_point(dp_id, analysis_dir, options[:results], manifest, options[:openstudio])
    rescue StandardError => e
      log "Datapoint #{dp_id} raised #{e.class}: #{e.message}"
      'Fail'
    end
    overall_failures += 1 if status != 'Success'
    log "Datapoint #{dp_id}: #{status}"
  end

  File.write(File.join(options[:results], "chunk_#{ci}.done"), Time.now.iso8601)
  log "Chunk #{ci} done"
end

log "Runner finished (#{overall_failures} non-success datapoints)"
