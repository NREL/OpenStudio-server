# simple script to copy required files
require 'optparse'
require 'fileutils'
require 'pathname'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: run_energyplus [options]"
  options[:energyplus] = "C:/EnergyPlusV7-2-0/energyplus.exe"
  options[:idd] = "C:/EnergyPlusV7-2-0/Energy+.idd"
  options[:os_path] = "C:/Program Files (x86)/OpenStudio 0.11.3/Ruby"
  options[:weather] = "C:/EnergyPlusV7-2-0/weather/USA_CO_Golden-NREL.724666_TMY3.epw"
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

  opts.on("--support-files [list_of_support_files]", Array, "Paths of Support Files") do |path|
    options[:support_files] = path
  end
end.parse!

puts "options = #{options.inspect}"

current_dir = Dir.pwd
puts "current directory is: #{current_dir}"
Dir.chdir(options[:path])
puts "changed directory to analysis: #{Dir.pwd}"
FileUtils.mkdir_p("./run") #create run folder to either execute the simulations, or to copy back

use_dev_shm = false
dest_dir = nil
if use_dev_shm
  dest_dir = Pathname.new("/dev/shm/") + Pathname.new(options[:path]) + "run"
  puts dest_dir
else
  dest_dir = Pathname.new("./run")
end

puts "forcing destination directory: #{dest_dir}"

FileUtils.mkdir_p(dest_dir)
#can't create symlinks because the /vagrant mount is actually a windows mount
FileUtils.copy(options[:energyplus], "#{dest_dir}/#{File.basename(options[:energyplus])}")
FileUtils.copy(options[:idd], "#{dest_dir}/#{File.basename(options[:idd])}")
FileUtils.copy(options[:osm], "#{dest_dir}/in.osm")
FileUtils.copy(options[:idf], "#{dest_dir}/in.idf")
FileUtils.copy(options[:weather], "#{dest_dir}/in.epw")


if options[:postprocess]
  #FileUtils.copy("./postproc.rb", "./run/postproc.rb")
end


begin
  Dir.chdir(dest_dir)

  #create stdout
  File.open('stdout','w') do |file|
    IO.popen('energyplus') { |io| while (line = io.gets) do file << line end }
  end

  if !options[:postprocess].nil?
    puts "running post process script"
    FileUtils.copy(options[:postprocess], "./postproc.rb")
    if !options[:support_files].nil? 
      options[:support_files].each do |support_file|
        FileUtils.copy(support_file, File.basename(support_file))
      end
    end
    puts "ruby -I#{options[:os_path]} postproc.rb"
    IO.popen("ruby -I'#{options[:os_path]}' postproc.rb") { |io| while (line = io.gets) do puts line end }
#    IO.popen("ruby postproc.rb") { |io| while (line = io.gets) do puts line end }

  end

rescue Exception => e  
  puts e.message  
  puts e.backtrace.inspect  
  
ensure
  done_dir = File.expand_path("..", Dir.pwd)
  File.open("#{done_dir}/done.receipt", 'w') {|f| f << Time.now}

  Dir.chdir(current_dir)

  if use_dev_shm
    #copy the results back to scratch
    files = Pathname.glob(dest_dir + "*")
    files.each do |file|
      FileUtils.cp(file, options[:path] + "/run/#{File.basename(file)}" )
    end
    FileUtils.rm_r(dest_dir)
  end

end

