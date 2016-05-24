#*******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#*******************************************************************************

# Initialize workers with required data.  This is called via bundler therefore, only gems that are installed on the
# server are able to be used. To add a new library/gem, make sure to add it to the Gemfile and re-configure the
# server/worker.

require 'bundler'
begin
  Bundler.setup
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'optparse'
require 'fileutils'
require 'logger'

puts "Parsing Input: #{ARGV}"

# parse arguments with optparse
options = {}
optparse = OptionParser.new do |opts|
  opts.on('-a', '--analysis_id UUID', String, 'UUID of the analysis.') do |analysis_id|
    options[:analysis_id] = analysis_id
  end

  opts.on('-s', '--state initialize_or_finalize ', String, 'Initializing or finalizing') do |state|
    options[:state] = state
  end
end
optparse.parse!

unless options[:analysis_id]
  # required argument is missing
  puts optparse
  exit
end

unless options[:state]
  puts "State is required (either 'initialize' or 'finalize')"
  exit
end

# Set the result of the project for R to know that this finished
result = false
begin
  # Logger for the simulate datapoint
  analysis_dir = "/mnt/openstudio/analysis_#{options[:analysis_id]}"
  FileUtils.mkdir_p analysis_dir unless Dir.exist? analysis_dir
  logger = Logger.new("#{analysis_dir}/worker_#{options[:state]}.log")

  logger.info "Running #{__FILE__}"

  # Download the zip file from the server
  download_file = "#{analysis_dir}/analysis.zip"
  download_url = "http://openstudio.server/analyses/#{options[:analysis_id]}/download_analysis_zip"
  logger.info "Downloading analysis.zip from #{download_url} to #{download_file}"
  `curl -o #{download_file} #{download_url}`
  `cd #{analysis_dir} && unzip -o #{download_file}`

  # Find any custom worker files -- should we just call these via system ruby? Then we could have any gem that is installed (not bundled)
  files = Dir["#{analysis_dir}/lib/worker_#{options[:state]}/*.rb"].map { |n| File.basename(n) }.sort
  logger.info "The following custom worker #{options[:state]} files were found #{files}"
  files.each do |f|
    f_fullpath = "#{analysis_dir}/lib/worker_#{options[:state]}/#{f}"
    f_argspath = "#{File.dirname(f_fullpath)}/#{File.basename(f_fullpath, '.*')}.args"
    logger.info "Running #{options[:state]} script #{f_fullpath}"

    # Each worker script has a very specific format and should be loaded and run as a class
    require f_fullpath

    # Remove the digits that specify the order and then create the class name
    klass_name = File.basename(f, '.*').gsub(/^\d*_/, '').split('_').map(&:capitalize).join

    # instantiate a class
    klass = Object.const_get(klass_name).new

    # check if there is an argument json that accompanies the class
    args = nil
    logger.info "Looking for argument file #{f_argspath}"
    if File.exist?(f_argspath)
      logger.info "argument file exists #{f_argspath}"
      args = eval(File.read(f_argspath))
      logger.info "arguments are #{args}"
    end

    r = klass.run(*args)
    logger.info "Script returned with #{r}"

    klass.finalize if klass.respond_to? :finalize
  end

  result = true
rescue => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  puts log_message
  logger.info log_message if logger
ensure
  logger.info "Finished #{__FILE__}" if logger
  logger.close if logger

  # always print out the state at the end
  puts result # as a string? (for R to parse correctly?)
end
