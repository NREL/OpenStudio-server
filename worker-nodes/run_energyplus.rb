# simple script to copy required files
require 'optparse'
require 'fileutils'
require 'pathname'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: run_energyplus [options]"
  options[:energyplus] = "/usr/local/EnergyPlus-8-0-0/EnergyPlus"
  options[:idd] = "/usr/local/EnergyPlus-8-0-0/Energy+.idd"
  options[:os_path] = "/usr/local/lib/ruby/site_ruby/2.0.0"
  options[:weather] = "../weather/USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw"
  options[:osm] = "./tests/initial.osm"
  options[:idf] = "./tests/initial.idf"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-e", "--energyplus-path [path]", String, "Path to EnergyPlus") do |path|
    options[:energyplus] = path
  end

  opts.on("--idd-path [path]", String, "Path to EnergyPlus IDD") do |path|
    options[:idd] = path
  end

  opts.on("--os-path [path]", String, "Path to OpenStudio Ruby Path") do |path|
    options[:os_path] = path
  end

  opts.on("-a", "--analysis-path [path]", String, "Path to directory to run") do |path|
    options[:path] = path
  end

  opts.on("-i", "--input-file [path]", String, "Path to IDF Input File") do |path|
    options[:idf] = path
  end

  opts.on("-o", "--osm-input-file [path]", String, "Path to OSM Input File") do |path|
    options[:osm] = path
  end

  opts.on("-d", "--energyplus-idd [iddpath]", String, "Path to EnergyPlus IDD") do |path|
    options[:idd] = path
  end

  opts.on("-w", "--weather-file [weatherpath]", String, "Full Path to EnergyPlus Weather") do |path|
    options[:weather] = path
  end

  opts.on("-p", "--postprocess [postprocessfile]", String, "Path to Post Process Script") do |path|
    options[:postprocess] = path
  end

  options[:support_files] = []
  opts.on("--support-files [list_of_support_files]", Array, "Paths of Support Files") do |path|
    options[:support_files] = path
  end
end.parse!

puts "options = #{options.inspect}"

current_dir = Dir.pwd
puts "current directory is: #{current_dir}"
Dir.chdir(options[:path])
puts "changed directory to analysis: #{Dir.pwd}"
dest_dir = "./run"
FileUtils.mkdir_p(dest_dir) #create run folder to either execute the simulations, or to copy back

#can't create symlinks because the /vagrant mount is actually a windows mount
epath = File.dirname(options[:energyplus])
FileUtils.copy("#{epath}/libbcvtb.so", "#{dest_dir}/libbcvtb.so")
FileUtils.copy("#{epath}/libepexpat.so", "#{dest_dir}/libepexpat.so")
FileUtils.copy("#{epath}/libepfmiimport.so", "#{dest_dir}/libepfmiimport.so")
FileUtils.copy("#{epath}/libDElight.so", "#{dest_dir}/libDElight.so")
FileUtils.copy("#{epath}/libDElight.so", "#{dest_dir}/libDElight.so")
FileUtils.copy("#{epath}/ExpandObjects", "#{dest_dir}/ExpandObjects")
FileUtils.copy(options[:energyplus], "#{dest_dir}/#{File.basename(options[:energyplus])}")
FileUtils.copy(options[:idd], "#{dest_dir}/#{File.basename(options[:idd])}")
FileUtils.copy(options[:osm], "#{dest_dir}/in.osm")
FileUtils.copy(options[:idf], "#{dest_dir}/in.idf")
FileUtils.copy(options[:weather], "#{dest_dir}/in.epw")


begin
  Dir.chdir(dest_dir)

  File.open('stdout-expandobject','w') do |file|
    IO.popen('ExpandObjects') { |io| while (line = io.gets) do file << line end }
  end

  # Check if expand objects did anythying
  if File.exists?("expanded.idf")
    FileUtils.mv("in.idf", "pre-expand.idf", force: true) if File.exists?("in.idf")
    FileUtils.mv("expanded.idf", "in.idf", force: true )
  end

  #create stdout
  File.open('stdout-energyplus','w') do |file|
    IO.popen('EnergyPlus') { |io| while (line = io.gets) do file << line end }
  end

  if !options[:postprocess].nil?
    puts "running post process script"
    FileUtils.copy(options[:postprocess], "./post_process.rb")
    options[:support_files].each do |support_file|
      FileUtils.copy(support_file, File.basename(support_file))
    end

    IO.popen("ruby -I#{options[:os_path]} post_process.rb") { |io| while (line = io.gets) do puts line end }
  end

rescue Exception => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  puts log_message
ensure
  Dir.chdir(current_dir)
  puts "completed energyplus"
end