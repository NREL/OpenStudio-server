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

# Determines if OS is Windows
#
def is_windows?
  win_patterns = [
      /bccwin/i,
      /cygwin/i,
      /djgpp/i,
      /mingw/i,
      /mswin/i,
      /wince/i,
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
    ::Timeout::timeout(1) do
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
def kill_rails_thread(rails_thread)
  begin
    ::Process.kill('KILL', rails_thread.value)
  rescue
    $logger.error 'Attempted to kill rails process. The success of the attempt is unclear'
    return
  end
  $logger.error 'Killed the rails process'
end

# Kill the mongod thread in start_local
#
def kill_mongod_thread(mongod_thread)
  begin
    ::Process.kill('KILL', mongod_thread.value)
  rescue
    $logger.error 'Attempted to kill mongod process. The success of the attempt is unclear'
    fail 1
  end
  $logger.error 'Killed the mongod process.'
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
  mongod_command_path = ::File.absolute_path(::File.join(__FILE__,'../local/mongo_command'))
  mongod_log_path = ::File.absolute_path(::File.join(project_directory, 'logs'))
  mongo_db_directory = ::File.absolute_path(::File.join(project_directory, 'data/db'))
  dj_server_command_path = ::File.absolute_path(::File.join(__FILE__,'../local/dj_server_command'))
  dj_worker_command_path = ::File.absolute_path(::File.join(__FILE__,'../local/dj_worker_command'))
  rails_command_path = ::File.absolute_path(::File.join(__FILE__,'../local/rails_command'))
  rails_log_path = ::File.absolute_path(::File.join(project_directory, 'logs'))

  mongod_port = find_available_port 27017, 100
  $logger.debug "Mongo port will be #{mongod_port}"
  $logger.error 'Unable to find port for mongo' unless mongod_port
  fail 1  unless mongod_port
  rails_port = find_available_port 8080, 100
  $logger.debug "Rails port will be #{rails_port}"
  $logger.error 'Unable to find port for rails' unless rails_port
  fail 1 unless rails_port

  state_file = ::File.join(project_directory, cluster_name + '_configuration.json')
  receipt_file = ::File.join(project_directory, cluster_name + '_configuration.receipt')
  ::File.delete state_file if ::File.exists? state_file
  ::File.delete receipt_file if ::File.exists? receipt_file

  i = 1
  if is_windows?
    mongod_command = "\"#{ruby_path}\" \"#{mongod_command_path}\" -w -p #{mongod_port} \"#{mongod_log_path}\" "\
      "\"#{mongo_directory}\" \"#{mongo_db_directory}\""
    rails_command = "\"#{ruby_path}\" \"#{rails_command_path}\" -w -p #{rails_port} \"#{ruby_path}\" "\
      "\"#{rails_log_path}\" \"#{project_directory}\" #{mongod_port}"
    dj_server_command = "\"#{ruby_path}\" \"#{dj_server_command_path}\" -w \"#{ruby_path}\" \"#{rails_log_path}\" "\
      "\"#{project_directory}\" \"#{mongod_port}\" \"#{rails_port}\""
    dj_worker_commands = []
    until i > worker_number
        dj_worker_commands << "\"#{ruby_path}\" \"#{dj_worker_command_path}\" -w \"#{ruby_path}\" "\
          "\"#{rails_log_path}\" \"#{project_directory}\" \"#{mongod_port}\" \"#{rails_port}\" #{i}"
        i += 1
    end
  else
    mongod_command = "#{ruby_path} #{mongod_command_path} -p #{mongod_port} #{mongod_log_path} #{mongo_directory} "\
      "#{mongo_db_directory}"
    rails_command = "#{ruby_path} #{rails_command_path} -p #{rails_port} #{ruby_path} #{rails_log_path} "\
      "#{project_directory} #{mongod_port}"
    dj_server_command = "#{ruby_path} #{dj_server_command_path} #{ruby_path} #{rails_log_path} #{project_directory} "\
      "#{mongod_port} #{rails_port}"
    dj_worker_commands = []
    until i > worker_number
      dj_worker_commands << "#{ruby_path} #{dj_worker_command_path} #{ruby_path} #{rails_log_path} "\
        "#{project_directory} #{mongod_port} #{rails_port} #{i}"
      i += 1
    end
  end

  if debug
    mongod_command += ' --debug'
    rails_command += ' --debug'
    dj_server_command += ' --debug'
    [mongod_command, rails_command, dj_server_command].each { |cmd| $logger.debug "Command for local CLI: #{cmd}" }
    dj_worker_commands.each { |cmd| cmd += ' --debug'; $logger.debug "Command for local CLI: #{cmd}" }
  end

  mongod_thread = ::Thread.new{ spawn(mongod_command) }
  mongod_pid = nil
  begin
    ::Timeout.timeout(60) {
      mongod_started = false
      until mongod_started
        sleep(0.01)
        mongod_started = true if is_port_open? mongod_port
      end
      mongod_pid = mongod_thread.value
    }
  rescue ::Timeout::Error
    $logger.error 'Mongod failed to launch, likely due to another mongod instance accessing the same db'
    kill_mongod_thread(mongod_thread)
    fail 1
  end
  $logger.error 'Unable to access mongod PID. Please investigate' unless mongod_pid
  $logger.debug "MONGOD STARTED WITH PID #{mongod_pid}"

  rails_thread = ::Thread.new{ spawn(rails_command) }
  rails_pid = nil
  begin
    ::Timeout.timeout(40) {
      rails_started = false
      until rails_started
        sleep(0.01)
        rails_started = true if is_port_open? rails_port
      end
      rails_pid = rails_thread.value
    }
  rescue ::Timeout::Error
    $logger.error 'Rails failed to launch'
    kill_rails_thread(rails_thread)
    kill_mongod_thread(mongod_thread)
    fail 1
  end
  $logger.error 'Unable to access rails PID. Please investigate' unless rails_pid
  $logger.debug "RAILS STARTED WITH PID #{rails_pid}"

  dj_threads = []
  dj_threads << ::Thread.new{ spawn(dj_server_command) }
  sleep 15 # TODO: replace this sleep with a check on if the dj_thread is initialized
  dj_worker_commands.each { |cmd| dj_threads << ::Thread.new{ spawn(cmd) }}

  # TODO: replace this sleep with a check on if the dj_thread is initialized
  sleep 15

  dj_pids = []
  dj_threads.each {|thread| dj_pids << thread.value}

  $logger.debug "DELAYED JOB MAY HAVE BEEN STARTED WITH PIDs #{dj_pids}"

  $logger.debug 'Instantiated all threads'

  hash_to_write = {server_url: "http://localhost:#{rails_port}", mongod_pid: mongod_pid, dj_pids: dj_pids, rails_pid: rails_pid}
  ::File.open(state_file, 'wb') { |f| f << ::JSON.pretty_generate(hash_to_write) }
  ::File.open(receipt_file, 'wb') { |_| }

  $logger.debug "Wrote local server configuration to #{state_file}"

  "http://localhost:#{rails_port}"
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
    ::Timeout::timeout (5) {
      ::Process.kill('SIGINT', rails_pid)
      ::Process.wait(rails_pid)
    }
  rescue Errno::ECHILD
  rescue Errno::ESRCH
    $logger.warn "UNABLE TO FIND RAILS PID #{rails_pid}"
  rescue ::Timeout::Error, Errno::EINVAL
    $logger.warn "Unable to kill the rails PID #{rails_pid} with SIGINT. Trying KILL"
    begin
      ::Timeout::timeout (5) {
        ::Process.kill('KILL', rails_pid)
        ::Process.wait(rails_pid)
      }
    rescue Errno::ECHILD
    rescue Errno::ESRCH
      $logger.warn "UNABLE TO FIND RAILS PID #{rails_pid}. SIGINT appears to have completed successfully"
    rescue ::Timeout::Error
      $logger.error "Unable to kill the rails PID #{rails_pid} with KILL"
      fail 1
    end
  end

  dj_pids.each do |dj_pid|
    begin
      ::Timeout::timeout (5) {
        ::Process.kill('SIGINT', dj_pid)
        ::Process.wait(dj_pid)
      }
    rescue Errno::ECHILD
    rescue Errno::ESRCH
      $logger.warn "UNABLE TO FIND DJ PID #{dj_pid}"
    rescue ::Timeout::Error, Errno::EINVAL
      $logger.warn "Unable to kill the dj PID #{dj_pid} with SIGINT. Trying KILL"
      begin
        ::Timeout::timeout (5) {
          ::Process.kill('KILL', dj_pid)
          ::Process.wait(dj_pid)
        }
      rescue Errno::ECHILD
      rescue Errno::ESRCH
        $logger.warn "UNABLE TO FIND DJ PID #{dj_pid}. SIGINT appears to have completed successfully"
      rescue ::Timeout::Error
        $logger.error "Unable to kill the dj PID #{dj_pid} with KILL"
        fail 1
      end
    end
  end

  begin
    ::Timeout::timeout (5) {
      ::Process.kill('SIGINT', mongod_pid)
      ::Process.wait(mongod_pid)
    }
  rescue Errno::ECHILD
  rescue Errno::ESRCH
    $logger.warn "UNABLE TO FIND MONGO PID #{mongod_pid}"
  rescue ::Timeout::Error, Errno::EINVAL
    $logger.warn "Unable to kill the mongo PID #{mongod_pid} with SIGINT. Trying KILL."
    begin
      ::Timeout::timeout (5) {
        ::Process.kill('KILL', mongod_pid)
        ::Process.wait(mongod_pid)
      }
    rescue Errno::ECHILD
    rescue Errno::ESRCH
      $logger.warn "UNABLE TO FIND MONGO PID #{mongod_pid}. SIGINT appears to have completed successfully"
    rescue ::Timeout::Error
      $logger.error "Unable to kill the mongo PID #{mongod_pid} with KILL"
      fail 1
    end
  end

  sleep 1 # Keep the return from beating the stdout text
end
