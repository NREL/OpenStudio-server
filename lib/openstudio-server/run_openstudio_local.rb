# Test the run_openstudio.rb script on a local build of OpenStudio

require 'openstudio'
require 'fileutils'

project_dir = File.dirname(__FILE__) + '../../testing/PATTest'

if not ARGV[0].nil?
  project_dir = ARGV[0]
end

run_dir = project_dir + "_LocalRun"
if File.exists?(run_dir)
  FileUtils.rm_rf(run_dir)
end
FileUtils.mkdir(run_dir)

# open the project and export to run_dir
project = OpenStudio::AnalysisDriver::SimpleProject::open(project_dir).get
project_zip = project.zipFileForCloud
FileUtils.cp(project_zip.to_s,run_dir + "/project.zip")
unzip = OpenStudio::UnzipFile.new(run_dir + "/project.zip")
unzip.extractAllFiles(run_dir)

# create run folder for last DataPoint 
data_point = project.analysis.dataPoints[project.analysis.dataPoints.size-1]
run_dir = run_dir + "/data_point_#{OpenStudio::removeBraces(data_point.uuid)}"
FileUtils.mkdir(run_dir)
dp_json = run_dir + "/data_point_in.json"
data_point.saveJSON(dp_json)

# run_openstudio.rb
worker_library_path = File.dirname(__FILE__) + '/../../worker-nodes'
run_openstudio_path = worker_library_path + '/run_openstudio.rb'
system("#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' -I'#{worker_library_path}' '#{run_openstudio_path}' -d '#{run_dir}' -u #{OpenStudio::removeBraces(data_point.uuid)} -r Local")


