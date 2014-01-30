require 'openstudio'

run_type = nil
if not ARGV[0].nil?
  run_type = ARGV[0].to_s
end

puts "\n\n"
puts "Exporting PATTest ============================================="
system ("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' ../lib/openstudio-server/export_project.rb PATTest")

puts "\n\n"
puts "Exporting BigPATTest =========================================="
system ("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' ../lib/openstudio-server/export_project.rb BigPATTest")

puts "\n\n"
puts "Creating DiskIOBenchmark ======================================"
system ("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' create_disk_io_benchmark_project.rb 64")

puts "\n\n"
puts "Exporting DiskIOBenchmark ====================================="
system ("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' ../lib/openstudio-server/export_project.rb DiskIOBenchmark")

if run_type == "vagrant"
  # run 4 data points each from PATTest and DiskIOBenchmark
  puts "\n\n"
  puts "Running Four Points in PATTest =============================="
  start = Time.now
  system ("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' ../lib/openstudio-server/run_project_vagrant.rb PATTest PATTest_Run 4")
  puts "Time to run 4 points of PATTest: " + (Time.now - start).to_s + " s"

  puts "\n\n"
  puts "Running Four Points in DiskIOBenchmark ======================"  
  start = Time.now
  system ("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' ../lib/openstudio-server/run_project_vagrant.rb DiskIOBenchmark DiskIOBenchmark_Run 4")
  puts "Time to run 4 points of DiskIOBenchmark: " + (Time.now - start).to_s + " s"
end
