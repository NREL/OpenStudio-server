require 'optparse'
require 'fileutils'

puts "Parsing Input: #{ARGV}"

# parse arguments with optparse
options = Hash.new
optparse = OptionParser.new do |opts|

  opts.on('-u', '--uuid UUID', String, "UUID of the data point to run with no braces.") do |s|
    options[:uuid] = s
  end

  options[:run_shm] = false
  opts.on('-s', '--run-shm', "Run on SHM Volume") do
    options[:run_shm] = true
  end

  options[:run_shm_dir] = "/run/shm"
  opts.on('-D', '--shm-dir SHM_PATH', String, "Path of the SHM Volume on the System.") do |s|
    options[:run_shm_dir] = s
  end
end

optparse.parse!

puts "Parsed Input: #{optparse}"

puts "Checking Arguments"
if not options[:uuid]
  # required argument is missing
  puts optparse
  exit
end

directory = nil
analysis_dir = "/mnt/openstudio"
store_directory = "/mnt/openstudio/analysis/data_point_#{options[:uuid]}"

# use /run/shm on AWS (if possible)
if Dir.exists?(options[:run_shm_dir]) && options[:run_shm]
  analysis_dir = "#{options[:run_shm_dir]}/openstudio"
  directory = "#{options[:run_shm_dir]}/openstudio/analysis/data_point_#{options[:uuid]}"
else
  directory = store_directory
end

puts "Simulation Run Directory is #{directory}"

# create data point directory
if File.exist?(directory)
  FileUtils.rm_rf(directory)
end

FileUtils.mkdir_p(directory)
FileUtils.mkdir_p(store_directory)

puts "Analysis in #{analysis_dir}; Running in #{directory}; Storing results in #{store_directory}"

# copy the file to the run directory and run
# removing all the files that may have been there.
FileUtils.copy("/mnt/openstudio/run_openstudio_lhs.rb", "#{directory}/run_openstudio_lhs.rb")

# call the run openstudio script
command = "ruby -I/usr/local/lib/ruby/site_ruby/2.0.0/ #{directory}/run_openstudio_lhs.rb -u #{options[:uuid]} -d #{directory} -r AWS > #{directory}/#{options[:uuid]}.log"
puts command
result = `#{command}`
puts "command result #{result}"

# put the data back into the "long term store"
if options[:run_shm]
  # only grab the zip/log files and put back in store_directory
  zip_file = "#{directory}/data_point_#{options[:uuid]}.zip"
  dest_zip_file = "#{store_directory}/data_point_#{options[:uuid]}.zip"
  puts "Trying to move zip file from #{zip_file} to #{dest_zip_file}"
  if File.exists?(zip_file)
    FileUtils.rm_f(dest_zip_file) if File.exists?(dest_zip_file)
    puts "Moving zip file"
    FileUtils.move(zip_file, dest_zip_file)
  end

  log_file = "#{directory}/#{options[:uuid]}.log"
  dest_log_file = File.expand_path("#{store_directory}/../#{options[:uuid]}-run_os.log")
  if File.exists?(log_file)
    FileUtils.rm_f(dest_log_file) if File.exists?(dest_log_file)
    FileUtils.move(log_file, dest_log_file)
  end

  puts "Removing directory from SHM #{directory}"
  FileUtils.rm_rf(directory) if Dir.exist?(directory)
end

# TODO: WARNING SHM will cause a problem when downloading the zip until this is fixed:
# TODO: Need to communicate back to the database here because we can get a race condition with the download of the zip file

# Communicate the object function here
puts "0"
