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
end
optparse.parse!

unless options[:analysis_id]
  # required argument is missing
  puts optparse
  exit
end

# Set the result of the project for R to know that this finished
result = false

begin
  # Logger for the simulate datapoint
  analysis_dir = "/mnt/openstudio/analysis_#{options[:analysis_id]}"
  FileUtils.mkdir_p analysis_dir unless Dir.exist? analysis_dir
  logger = Logger.new("#{analysis_dir}/worker_init.log")

  logger.info "Running #{__FILE__}"

  # Go through all init level scripts and run them (similar to linux init scripts).
  # lrwxrwxrwx 1 root root  29 Sep 16 23:00 K10unattended-upgrades -> ../init.d/unattended-upgrades
  # lrwxrwxrwx 1 root root  26 Sep 16 23:00 K15landscape-client -> ../init.d/landscape-client
  # lrwxrwxrwx 1 root root  15 Sep 16 23:00 K20rsync -> ../init.d/rsync
  # lrwxrwxrwx 1 root root  24 Sep 16 23:00 K20screen-cleanup -> ../init.d/screen-cleanup
  # lrwxrwxrwx 1 root root  32 Sep 16 23:47 K20virtualbox-guest-utils -> ../init.d/virtualbox-guest-utils
  # lrwxrwxrwx 1 root root  16 Sep 16 23:48 K21puppet -> ../init.d/puppet
  # lrwxrwxrwx 1 root root  23 Sep 16 23:00 K38open-vm



  result = true
rescue => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  puts log_message
  logger.info log_message if logger
ensure
  logger.info "Finished #{__FILE__}" if logger
  logger.close if logger

  # always print out the state at the end
  puts result
end
