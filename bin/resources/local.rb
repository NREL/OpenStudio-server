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
require 'open3'

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

# Kill the rails thread in start_local
#
def kill_rails_process(rails_pid)
  begin
    ::Process.kill('KILL', rails_pid)
  rescue
    $logger.error 'Attempted to kill rails process. The success of the attempt is unclear'
    return
  end
  $logger.error 'Killed the rails process'
end

# Kill the mongod thread in start_local
#
def kill_mongod_process(mongod_pid)
  begin
    ::Process.kill('KILL', mongod_pid)
  rescue
    $logger.error 'Attempted to kill mongod process. The success of the attempt is unclear'
    raise 1
  end
  $logger.error 'Killed the mongod process.'
end

# Kill a delayed_jobs thread in start_local
#
def kill_dj_process(dj_pid)
  begin
    ::Process.kill('KILL', dj_pid)
  rescue
    $logger.error "Attempted to kill dj process with PID `#{dj_pid}`. The success of the attempt is unclear"
    raise 1
  end
  $logger.error "Killed the dj process with PID `#{dj_pid}`"
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

  mongod_pid, mongod_out, mongod_status = nil
  begin
    ::Timeout.timeout(10) do
      mongod_out, mongod_status = ::Open3.capture2e(mongod_command)
      mongod_started = false
      until mongod_started
        sleep(0.01)
        mongod_started = true if is_port_open? mongod_port
      end
      mongod_pid = mongod_status.pid
    end
  rescue ::Timeout::Error
    $logger.error "Mongod failed to launch. Please refer to `#{::File.join(project_directory, 'logs', 'mongod.log')}`"\
      ". The output of the command was:\n#{mongod_out}"
    kill_mongod_process(mongod_pid)
    raise 1
  else
    if mongod_status.to_i != 0
      $logger.error "Mongod returned non-zero status code `#{mongod_status.to_i}`. Please refer to "\
        "`#{::File.join(project_directory, 'logs', 'mongod.log')}`. The output of the command was:\n`#{mongod_out}`"
      kill_mongod_process(mongod_pid)
      raise 1
    end
  end
  $logger.error 'Unable to access mongod PID. Please investigate' unless mongod_pid
  $logger.debug "MONGOD STARTED WITH PID #{mongod_pid}"

  rails_pid, rails_out, rails_status = nil
  begin
    ::Timeout.timeout(40) do
      rails_out, rails_status = ::Open3.capture2e(rails_command)
      rails_started = false
      until rails_started
        sleep(0.01)
        rails_started = true if is_port_open? rails_port
      end
      rails_pid = rails_status.pid
    end
  rescue ::Timeout::Error
    $logger.error "Rails failed to launch. Please refer to `#{::File.join(project_directory, 'logs', 'rails.log')}`"\
      ". The output of the command was:\n#{rails_out}"
    kill_rails_process(rails_pid)
    kill_mongod_process(mongod_pid)
    raise 1
  else
    if rails_status.to_i != 0
      $logger.error "Rails returned non-zero status code `#{mongod_status.to_i}`. Please refer to "\
        "`#{::File.join(project_directory, 'logs', 'rails.log')}`. The output of the command was:\n`#{rails_out}`"
      kill_rails_process(rails_pid)
      kill_mongod_process(mongod_pid)
      raise 1
    end
  end
  $logger.error 'Unable to access rails PID. Please investigate' unless rails_pid
  $logger.debug "RAILS STARTED WITH PID #{rails_pid}"


  dj_server_pid, dj_server_out, dj_server_status = nil
  begin
    ::Timeout.timeout(5) do
      dj_server_out, dj_server_status = ::Open3.capture2e(dj_server_command)
      dj_server_pid = dj_server_status.pid
    end
  rescue ::Timeout::Error
    $logger.error "dj_server failed to launch. Please refer to `#{::File.join(project_directory, 'logs', 'dj_server.log')}`"\
      ". The output of the command was:\n#{dj_server_out}"
    kill_dj_process(dj_server_pid)
    kill_rails_process(dj_server_pid)
    kill_mongod_process(mongod_pid)
    raise 1
  else
    if dj_server_status.to_i != 0
      $logger.error "dj_server returned non-zero status code `#{dj_server_status.to_i}`. Please refer to "\
        "`#{::File.join(project_directory, 'logs', 'dj_server.log')}`. The output of the command was:\n`#{dj_server_out}`"
      kill_dj_process(dj_server_pid)
      kill_rails_process(rails_pid)
      kill_mongod_process(mongod_pid)
      raise 1
    end
  end
  $logger.error 'Unable to access dj_server PID. Please investigate' unless dj_server_pid
  $logger.debug "DELAYED JOBS SERVER MAY HAVE BEEN STARTED WITH PID #{dj_server_pid}"

  dj_pids = [dj_server_pid]
  dj_worker_commands.each_with_index do |cmd, ind|
    dj_worker_pid, dj_worker_out, dj_worker_status = nil
    begin
      ::Timeout.timeout(5) do
        dj_worker_out, dj_worker_status = ::Open3.capture2e(cmd)
        dj_worker_pid = dj_worker_status.pid
        dj_pids << dj_worker_pid
      end
    rescue ::Timeout::Error
      $logger.error "dj_worker_#{ind} failed to launch. Please refer to `#{::File.join(project_directory, 'logs',
                                                                                     'dj_worker_' + ind + '.log')}`"\
        ". The output of the command was:\n#{dj_worker_out}"
      dj_pids.each { |pid| kill_dj_process(pid) }
      kill_rails_process(rails_pid)
      kill_mongod_process(mongod_pid)
      raise 1
    else
      if dj_worker_status.to_i != 0
        $logger.error "dj_worker_#{ind} returned non-zero status code `#{dj_worker_status.to_i}`. Please refer to "\
          "`#{::File.join(project_directory, 'logs', 'dj_worker_' + ind + '.log')}`. The output of the command was:"\
          "\n`#{dj_worker_out}`"
        dj_pids.each { |pid| kill_dj_process(pid) }
        kill_rails_process(rails_pid)
        kill_mongod_process(mongod_pid)
        raise 1
      end
    end
    $logger.error "Unable to access dj_worker_#{i} PID. Please investigate" unless dj_worker_pid
    $logger.debug "DELAYED JOBS WORKER #{i} MAY HAVE BEEN STARTED WITH PID #{dj_worker_pid}"
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
  begin
    ::Timeout.timeout (5) do
      ::Process.kill('SIGINT', rails_pid)
      ::Process.wait(rails_pid)
    end
  rescue Errno::ECHILD
  rescue Errno::ESRCH
    $logger.warn "UNABLE TO FIND RAILS PID #{rails_pid}"
  rescue ::Timeout::Error, Errno::EINVAL
    $logger.warn "Unable to kill the rails PID #{rails_pid} with SIGINT. Trying KILL"
    begin
      ::Timeout.timeout (5) do
        ::Process.kill('KILL', rails_pid)
        ::Process.wait(rails_pid)
      end
    rescue Errno::ECHILD
    rescue Errno::ESRCH
      $logger.warn "UNABLE TO FIND RAILS PID #{rails_pid}. SIGINT appears to have completed successfully"
    rescue ::Timeout::Error
      $logger.error "Unable to kill the rails PID #{rails_pid} with KILL"
      raise 1
    end
  end

  dj_pids.each do |dj_pid|
    begin
      ::Timeout.timeout (5) do
        ::Process.kill('SIGINT', dj_pid)
        ::Process.wait(dj_pid)
      end
    rescue Errno::ECHILD
    rescue Errno::ESRCH
      $logger.warn "UNABLE TO FIND DJ PID #{dj_pid}"
    rescue ::Timeout::Error, Errno::EINVAL
      $logger.warn "Unable to kill the dj PID #{dj_pid} with SIGINT. Trying KILL"
      begin
        ::Timeout.timeout (5) do
          ::Process.kill('KILL', dj_pid)
          ::Process.wait(dj_pid)
        end
      rescue Errno::ECHILD
      rescue Errno::ESRCH
        $logger.warn "UNABLE TO FIND DJ PID #{dj_pid}. SIGINT appears to have completed successfully"
      rescue ::Timeout::Error
        $logger.error "Unable to kill the dj PID #{dj_pid} with KILL"
        raise 1
      end
    end
  end

  begin
    ::Timeout.timeout (5) do
      ::Process.kill('SIGINT', mongod_pid)
      ::Process.wait(mongod_pid)
    end
  rescue Errno::ECHILD
  rescue Errno::ESRCH
    $logger.warn "UNABLE TO FIND MONGO PID #{mongod_pid}"
  rescue ::Timeout::Error, Errno::EINVAL
    $logger.warn "Unable to kill the mongo PID #{mongod_pid} with SIGINT. Trying KILL."
    begin
      ::Timeout.timeout (5) do
        ::Process.kill('KILL', mongod_pid)
        ::Process.wait(mongod_pid)
      end
    rescue Errno::ECHILD
    rescue Errno::ESRCH
      $logger.warn "UNABLE TO FIND MONGO PID #{mongod_pid}. SIGINT appears to have completed successfully"
    rescue ::Timeout::Error
      $logger.error "Unable to kill the mongo PID #{mongod_pid} with KILL"
      raise 1
    end
  end

  sleep 1 # Keep the return from beating the stdout text
end
