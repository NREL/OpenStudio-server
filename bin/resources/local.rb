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
require 'socket'
require 'json'

# Determines if OS is Windows
#
def is_windows?
  win_patterns = [
    /bccwin/i,
    /cygwin/i,
    /djgpp/i,
    /mingw/i,
    /mswin/i,
    /wince/i
  ]

  case RUBY_PLATFORM
    when *win_patterns
      return true
    else
      return false
  end
end

# Check to see if the port is open on the local computer
#
# @param port [Integer] localhost port to check
# @return [Bool] true if the port is open, false if it is closed or unavailable
#
def is_port_open?(port)
  begin
    ::Timeout.timeout(1) do
      begin
        s = TCPSocket.new('localhost', port)
        s.close
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EADDRNOTAVAIL
        return false
      end
    end
  rescue ::Timeout::Error
    return false
  end

  false
end

# Find the first available port within range
#
# @param starting [Integer] port to start search from
# @param range [Integer] number of ports to search before failing
# @return [Integer, false] either the first available port, or false if all ports in the range were open
#
def find_available_port(starting, range)
  test_port = starting - 1
  port_available = false
  until port_available || test_port == (starting + range)
    test_port += 1
    port_available = true unless is_port_open? test_port
  end
  return false unless port_available
  test_port
end

# Find all child-processes of the processes listed in the local_configuration.json file on Windows to ensure cleanup
#
# @param pid_json_path [String] absolute path for the local_configuration.json file
# @param recursion_limit [Int] maximum recursive depth to track PIDs to
# @return [nil] (over)writes the child_pids field in the local_configuration.json file
#
def find_windows_pids(pid_json_path, recursion_limit = 6)
  pid_hash = ::JSON.parse(File.read(pid_json_path), symbolize_names: true)
  pid_array = []
  pid_array << pid_hash[:mongod_pid] if pid_hash[:mongod_pid]
  pid_array += pid_hash[:dj_pids] if pid_hash[:dj_pids]
  pid_array << pid_hash[:rails_pid] if pid_hash[:rails_pid]
  pid_list = pid_array.clone
  pid_str = `WMIC PROCESS get Caption,ProcessId,ParentProcessId`.split("\n\n")
  pid_str.shift
  fully_recursed = false
  recursion_level = 0
  until fully_recursed
    recursion_level += 1
    prior_pid_list = pid_list
    pid_str.each do |p_desc|
      if pid_list.include? p_desc.gsub(/\s+/, ' ').split(' ')[-2].to_i
        child_pid = p_desc.gsub(/\s+/, ' ').split(' ')[-1].to_i
        pid_list << child_pid unless pid_list.include? child_pid
      end
    end
    fully_recursed = true if pid_list == prior_pid_list
    fully_recursed = true if recursion_level == recursion_limit
  end
  child_pids = pid_list - pid_array
  pid_hash[:child_pids] = child_pids
  ::File.open(pid_json_path, 'wb') { |f| f << ::JSON.pretty_generate(pid_hash) }
end

# Kill all started processes as defined in the local_configuration.json
#
# @param pid_json [String] absolute path for the local_configuration.json file
#
def kill_processes(pid_json)
  unless File.exist? pid_json
    $logger.error "File `#{pid_json}` not found. It is possible that processes have been orphaned."
    exit 1
  end
  windows = is_windows?
  find_windows_pids(pid_json) if windows
  pid_hash = ::JSON.parse(File.read(pid_json), symbolize_names: true)
  pid_array = []
  pid_array << pid_hash[:mongod_pid] if pid_hash[:mongod_pid]
  pid_array += pid_hash[:dj_pids] if pid_hash[:dj_pids]
  pid_array << pid_hash[:rails_pid] if pid_hash[:rails_pid]
  pid_array += pid_hash[:child_pids] if pid_hash[:child_pids]
  pid_array.each do |pid|
    begin
      if windows
        # Check if a process with this PID exists before attempting to kill
        pid_exists = system('tasklist /FI' + ' "PID eq ' + pid.to_s + '" 2>NUL | find /I /N "' + pid.to_s + '">NUL')
        if pid_exists
          system_return = system('taskkill', '/pid', pid.to_s, '/f', '/t')
          raise StandardError unless system_return
        else
          $logger.warn "No process with PID #{pid} exists, did not attempt to kill"
          next
        end
      else
        ::Process.kill('SIGKILL', pid)
      end
    rescue
      $logger.error "Attempted to kill process with PID `#{pid}`. The success of the attempt is unclear"
      next
    end
    $logger.debug "Killed process with PID `#{pid}`."
  end
  ::File.delete(pid_json)
end

# Start the local server and save pid information to the project_directory
#
# @param project_directory [String] directory of the project attempting to boot the local server
# @param mongo_directory [String] directory of the mongo install, (only matters for Windows)
# @param worker_number [Integer] how many worker instances to spin up, counting from one
# @return [String] URL of the started local server
#
def start_local_server(project_directory, mongo_directory, ruby_path, worker_number, debug)
  cluster_name = 'local'
  mongod_command_path = ::File.absolute_path(::File.join(__FILE__, '../local/mongo_command'))
  mongod_log_path = ::File.absolute_path(::File.join(project_directory, 'logs'))
  mongo_db_directory = ::File.absolute_path(::File.join(project_directory, 'data/db'))
  dj_server_command_path = ::File.absolute_path(::File.join(__FILE__, '../local/dj_server_command'))
  dj_worker_command_path = ::File.absolute_path(::File.join(__FILE__, '../local/dj_worker_command'))
  rails_command_path = ::File.absolute_path(::File.join(__FILE__, '../local/rails_command'))
  rails_log_path = ::File.absolute_path(::File.join(project_directory, 'logs'))

  mongod_port = find_available_port 27_017, 100
  $logger.debug "Mongo port will be #{mongod_port}"
  $logger.error 'Unable to find port for mongo' unless mongod_port
  exit 1 unless mongod_port
  rails_port = find_available_port 8080, 100
  $logger.debug "Rails port will be #{rails_port}"
  $logger.error 'Unable to find port for rails' unless rails_port
  exit 1 unless rails_port

  state_file = ::File.join(project_directory, cluster_name + '_configuration.json')
  receipt_file = ::File.join(project_directory, cluster_name + '_configuration.receipt')
  ::File.delete receipt_file if ::File.exist? receipt_file

  i = 1
  mongod_command = "\"#{ruby_path}\" \"#{mongod_command_path}\" -p #{mongod_port} \"#{mongod_log_path}\" "\
    "\"#{mongo_directory}\" \"#{mongo_db_directory}\" \"#{state_file}\" \"#{project_directory}\""
  rails_command = "\"#{ruby_path}\" \"#{rails_command_path}\" -p #{rails_port} \"#{ruby_path}\" "\
    "\"#{rails_log_path}\" \"#{project_directory}\" #{mongod_port} \"#{state_file}\""
  dj_server_command = "\"#{ruby_path}\" \"#{dj_server_command_path}\" \"#{ruby_path}\" \"#{rails_log_path}\" "\
    "\"#{project_directory}\" \"#{mongod_port}\" \"#{rails_port}\" \"#{state_file}\""
  dj_worker_commands = []
  until i > worker_number
    dj_worker_commands << "\"#{ruby_path}\" \"#{dj_worker_command_path}\" \"#{ruby_path}\" "\
      "\"#{rails_log_path}\" \"#{project_directory}\" \"#{mongod_port}\" \"#{rails_port}\" #{i} \"#{state_file}\""
    i += 1
  end

  if debug
    mongod_command += ' --debug'
    rails_command += ' --debug'
    dj_server_command += ' --debug'
    [mongod_command, rails_command, dj_server_command].each { |cmd| $logger.debug "Command for local CLI: #{cmd}" }
    dj_worker_commands.each { |cmd| cmd += ' --debug'; $logger.debug "Command for local CLI: #{cmd}" }
  end

  mongod_timeout = ::ENV['USE_TESTING_TIMEOUTS'] == 'true' ? 60 : 15
  begin
    ::Timeout.timeout(mongod_timeout) do
      success = system mongod_command
      unless success
        $logger.error "Mongod returned non-zero status code  `#{$?.exitstatus}`. Please refer to "\
        "`#{::File.join(project_directory, 'logs', 'mongod.log')}`."
        kill_processes(state_file)
        exit 1
      end
      mongod_started = false
      until mongod_started
        sleep(0.01)
        mongod_started = true if is_port_open? mongod_port
      end
    end
  rescue ::Timeout::Error
    $logger.error "Mongod failed to launch. Please refer to `#{::File.join(project_directory, 'logs', 'mongod.log')}`."
    kill_processes(state_file)
    exit 1
  end
  $logger.debug 'MONGOD STARTED'

  begin
    ::Timeout.timeout(120) do
      success = system(rails_command)
      unless success
        $logger.error "Rails returned non-zero status code `#{$?.exitstatus}`. Please refer to "\
        "`#{::File.join(project_directory, 'logs', 'rails.log')}`."
        kill_processes(state_file)
        exit 1
      end
      rails_started = false
      until rails_started
        sleep(0.01)
        rails_started = true if is_port_open? rails_port
      end
    end
  rescue ::Timeout::Error
    $logger.error "Rails failed to launch. Please refer to `#{::File.join(project_directory, 'logs', 'rails.log')}`."
    kill_processes(state_file)
    exit 1
  end
  $logger.debug 'RAILS STARTED'

  begin
    ::Timeout.timeout(15) do
      success = system(dj_server_command)
      unless success
        $logger.error "dj_server returned non-zero status code `#{$?.exitstatus}`. Please refer to "\
        "`#{::File.join(project_directory, 'logs', 'dj_server.log')}`."
        kill_processes(state_file)
        exit 1
      end
    end
  rescue ::Timeout::Error
    $logger.error "dj_server failed to launch. Please refer to `#{::File.join(project_directory, 'logs', 'dj_server.log')}`."
    kill_processes(state_file)
    exit 1
  end
  $logger.debug 'DELAYED JOBS SERVER MAY HAVE BEEN STARTED'

  dj_worker_commands.each_with_index do |cmd, ind|
    begin
      ::Timeout.timeout(15) do
        success = system(cmd)
        unless success
          $logger.error "dj_worker_#{ind} returned non-zero status code `#{$?.exitstatus}`. Please refer to "\
          "`#{::File.join(project_directory, 'logs', 'dj_worker_' + ind + '.log')}`."
          kill_processes(state_file)
          exit 1
        end
      end
    rescue ::Timeout::Error
      $logger.error "dj_worker_#{ind} failed to launch. Please refer to `#{::File.join(project_directory, 'logs',
                                                                                       'dj_worker_' + ind.to_s + '.log')}`."
      kill_processes(state_file)
      exit 1
    end
    $logger.debug "DELAYED JOBS WORKER #{ind} MAY HAVE BEEN STARTED"
    sleep 20 # TODO: Figure out how to determine if dj instance is initialized.
  end

  find_windows_pids(state_file) if is_windows?

  $logger.debug 'Instantiated all processes. Writing receipt file.'

  ::File.open(receipt_file, 'wb') { |_| }

  $logger.debug "Completed writing local server configuration to #{state_file}"
end

# Kill a PID according to OS
def kill_pid(pid, name, windows = false)
  if windows
    # Check if a process with this PID exists
    pid_exists = system('tasklist /FI' + ' "PID eq ' + pid.to_s + '" 2>NUL | find /I /N "' + pid.to_s + '">NUL')
    if pid_exists
      system_return = system('taskkill', '/pid', pid.to_s, '/f')
      unless system_return
        $logger.error "Failed to kill process with PID `#{pid}`"
        return false
      end
    else
      $logger.warn "No process with PID #{pid} exists, did not attempt to kill"
    end
    $logger.debug "Kill #{name} process with PID `#{pid}`"
  else
    begin
      ::Timeout.timeout (5) do
        ::Process.kill('SIGINT', pid)
        ::Process.wait(pid)
      end
    rescue Errno::ESRCH, Errno::ECHILD
      $logger.warn "Unable to find #{name} PID `#{pid}`. SIGINT appears to have completed successfully"
    rescue ::Timeout::Error, Errno::EINVAL
      $logger.warn "Unable to kill the #{name} PID `#{pid}` with SIGINT. Trying KILL"
      begin
        ::Timeout.timeout (5) do
          ::Process.kill('SIGKILL', pid)
          ::Process.wait(pid)
        end
      rescue Errno::ESRCH, Errno::ECHILD
        $logger.warn "Unable to find #{name} PID `#{pid}`. SIGKILL appears to have completed successfully"
      rescue ::Timeout::Error
        $logger.error "Unable to kill the #{name} PID `#{pid}` with KILL"
        return false
      rescue Exception => e
        $logger.error "Caught unexpected error `#{e.message}` (`#{e.inspect}`) while killing #{name} PID `#{pid}`."\
          " Backtrace: #{e.backtrace.join("\n")}"
        return false
      end
    rescue Exception => e
      $logger.error "Caught unexpected error `#{e.message}` (`#{e.inspect}`) while killing #{name} PID `#{pid}`."\
        " Backtrace: #{e.backtrace.join("\n")}"
      return false
    end
    $logger.debug "Killed #{name} process with PID `#{pid}`"
  end
  true
end

# Stop the local server
#
# @param rails_pid [Integer] the process id belonging to the rails instance
# @param dj_pids [Array] the array of process ids belonging to the delayed job instances
# @param mongod_pid [Integer] the process id belonging to the mongod instance
# @param child_pids [Array] the array of process ids which may not otherwise be killed on Windows
# @return [Void]
#
def stop_local_server(rails_pid, dj_pids, mongod_pid, child_pids = [])
  successful = true
  windows = is_windows?
  dj_pids.reverse.each do |dj_pid|
    pid_kill_success = kill_pid(dj_pid, 'delayed-jobs', windows)
    successful = false unless pid_kill_success
  end

  pid_kill_success = kill_pid(rails_pid, 'rails', windows)
  successful = false unless pid_kill_success

  pid_kill_success = kill_pid(mongod_pid, 'mongod', windows)
  successful = false unless pid_kill_success

  child_pids.each do |child_pid|
    kill_pid(child_pid, 'child-process', windows)
    successful = false unless pid_kill_success
  end

  sleep 2 # Keep the return from beating the stdout text

  unless successful
    $logger.error 'Not all PID kills were successful. Please investigate the error logs.'
    return false
  end

  true
end
