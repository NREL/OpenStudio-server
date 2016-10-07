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


# Kill all started processes as defined in the local_configuration.json
#
def kill_processes(pid_json)
  unless File.exist? pid_json
    $logger.error "File `#{pid_json}` not found. It is possible that processes have been orphaned."
    raise 1
  end
  pid_hash = ::JSON.parse(File.read(pid_json), symbolize_names: true)
  pid_array = []
  pid_array << pid_hash[:mongod_pid] if pid_hash[:mongod_pid]
  pid_array + pid_hash[:dj_pids] if pid_hash[:dj_pids]
  pid_array << pid_hash[:rails_pid] if pid_hash[:rails_pid]
  pid_array.each do |pid|
    begin
      ::Process.kill('KILL', pid)
    rescue
      $logger.error "Attempted to kill process with PID `#{pid}`. The success of the attempt is unclear"
      next
    end
    $logger.error "Killed process with PID `#{pid}`."
  end
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
  raise 1 unless mongod_port
  rails_port = find_available_port 8080, 100
  $logger.debug "Rails port will be #{rails_port}"
  $logger.error 'Unable to find port for rails' unless rails_port
  raise 1 unless rails_port

  state_file = ::File.join(project_directory, cluster_name + '_configuration.json')
  receipt_file = ::File.join(project_directory, cluster_name + '_configuration.receipt')
  ::File.delete state_file if ::File.exist? state_file
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

  begin
    ::Timeout.timeout(10) do
      success = system (mongod_command)
      unless success
        $logger.error "Mongod returned non-zero status code  `#{$?.exitstatus}`. Please refer to "\
        "`#{::File.join(project_directory, 'logs', 'mongod.log')}`."
        kill_processes(state_file)
        raise 1
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
    raise 1
  end
  $logger.debug 'MONGOD STARTED'

  begin
    ::Timeout.timeout(40) do
      success = system(rails_command)
      unless success
        $logger.error "Rails returned non-zero status code `#{$?.exitstatus}`. Please refer to "\
        "`#{::File.join(project_directory, 'logs', 'rails.log')}`."
        kill_processes(state_file)
        raise 1
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
    raise 1
  end
  $logger.debug 'RAILS STARTED'

  begin
    ::Timeout.timeout(5) do
      success = system(dj_server_command)
      unless success
        $logger.error "dj_server returned non-zero status code `#{$?.exitstatus}`. Please refer to "\
        "`#{::File.join(project_directory, 'logs', 'dj_server.log')}`."
        kill_processes(state_file)
        raise 1
      end
    end
  rescue ::Timeout::Error
    $logger.error "dj_server failed to launch. Please refer to `#{::File.join(project_directory, 'logs', 'dj_server.log')}`."
    kill_processes(state_file)
    raise 1
  end
  $logger.debug 'DELAYED JOBS SERVER MAY HAVE BEEN STARTED'

  dj_worker_commands.each_with_index do |cmd, ind|
    begin
      ::Timeout.timeout(5) do
        success = system(cmd)
        unless success
          $logger.error "dj_worker_#{ind} returned non-zero status code `#{$?.exitstatus}`. Please refer to "\
          "`#{::File.join(project_directory, 'logs', 'dj_worker_' + ind + '.log')}`."
          kill_processes(state_file)
          raise 1
        end
      end
    rescue ::Timeout::Error
      $logger.error "dj_worker_#{ind} failed to launch. Please refer to `#{::File.join(project_directory, 'logs',
                                                                                     'dj_worker_' + ind + '.log')}`."
      kill_processes(state_file)
      raise 1
    end
    $logger.debug "DELAYED JOBS WORKER #{i} MAY HAVE BEEN STARTED"
    sleep 20 # TODO: Figure out how to determine if dj instance is initialized.
  end

  $logger.debug 'Instantiated all processes. Writing receipt file.'

  ::File.open(receipt_file, 'wb') { |_| }

  $logger.debug "Completed writing local server configuration to #{state_file}"
end

# Stop the local server
#
# @param rails_pid [Integer] the process id belonging to the rails instance
# @param dj_pids [Array] the array of process ids belonging to the delayed job instances
# @param mongod_pid [Integer] the process id belonging to the mongo instance
# @return [Void]
#
def stop_local_server(rails_pid, dj_pids, mongod_pid)
  dj_pids.reverse.each do |dj_pid|
    begin
      ::Timeout.timeout (5) do
        ::Process.kill('SIGINT', dj_pid)
        ::Process.wait(dj_pid)
      end
    rescue Errno::ESRCH
      $logger.warn "Unable to find delayed-jobs PID #{dj_pid}"
    rescue ::Timeout::Error, Errno::EINVAL
      $logger.warn "Unable to kill the dj PID #{dj_pid} with SIGINT. Trying KILL"
      begin
        ::Timeout.timeout (5) do
          ::Process.kill('KILL', dj_pid)
          ::Process.wait(dj_pid)
        end
      rescue Errno::ESRCH
        $logger.warn "Unable to find delayed-jobs PID #{dj_pid}. SIGINT appears to have completed successfully"
      rescue ::Timeout::Error
        $logger.error "Unable to kill the dj PID #{dj_pid} with KILL"
        raise 1
      rescue Exception => e
        raise unless e.is_a?(Errno::ECHILD)
      end
    rescue Exception => e
      raise unless e.is_a?(Errno::ECHILD)
    end
    $logger.debug "Killed delayed-jobs process with PID `#{dj_pid}`"
  end

  begin
    ::Timeout.timeout (5) do
      ::Process.kill('SIGINT', rails_pid)
      ::Process.wait(rails_pid)
    end
  rescue Errno::ESRCH
    $logger.warn "Unable to find rails PID #{rails_pid}"
  rescue ::Timeout::Error, Errno::EINVAL
    $logger.warn "Unable to kill the rails PID #{rails_pid} with SIGINT. Trying KILL"
    begin
      ::Timeout.timeout (5) do
        ::Process.kill('KILL', rails_pid)
        ::Process.wait(rails_pid)
      end
    rescue Errno::ESRCH
      $logger.warn "Unable to find rails PID #{rails_pid}. SIGINT appears to have completed successfully"
    rescue ::Timeout::Error
      $logger.error "Unable to kill the rails PID #{rails_pid} with KILL"
      raise 1
    rescue Exception => e
      raise unless e.is_a?(Errno::ECHILD)
    end
  rescue Exception => e
    raise unless e.is_a?(Errno::ECHILD)
  end
  $logger.debug "Killed rails process with PID `#{rails_pid}`"

  begin
    ::Timeout.timeout (5) do
      ::Process.kill('SIGINT', mongod_pid)
      ::Process.wait(mongod_pid)
    end
  rescue Errno::ESRCH
    $logger.warn "Unable to find mongod PID #{mongod_pid}"
  rescue ::Timeout::Error, Errno::EINVAL
    $logger.warn "Unable to kill the mongod PID #{mongod_pid} with SIGINT. Trying KILL."
    begin
      ::Timeout.timeout (5) do
        ::Process.kill('KILL', mongod_pid)
        ::Process.wait(mongod_pid)
      end
    rescue Errno::ESRCH
      $logger.warn "Unable to find mongod PID #{mongod_pid}. SIGINT appears to have completed successfully"
    rescue ::Timeout::Error
      $logger.error "Unable to kill the mongod PID #{mongod_pid} with KILL"
      raise 1
    rescue Exception => e
      raise unless e.is_a?(Errno::ECHILD)
    end
  rescue Exception => e
    raise unless e.is_a?(Errno::ECHILD)
  end
  $logger.debug "Killed mongod process with PID `#{mongod_pid}`"

  sleep 1 # Keep the return from beating the stdout text
end
