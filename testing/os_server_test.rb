require 'openstudio'

system ("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' ../lib/openstudio-server/export_project.rb PATTest")
system ("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' ../lib/openstudio-server/export_project.rb BigPATTest")
system ("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' create_disk_io_benchmark_project.rb 64")
system ("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' ../lib/openstudio-server/export_project.rb DiskIOBenchmark")
