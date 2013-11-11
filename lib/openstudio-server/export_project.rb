require 'openstudio'
require 'fileutils'

# ARGV[0] - the name of the project to export, e.g. 'PATTest'
#
# This script will export the named project to ARGV[0] + 'Export'

project_dir = ARGV[0].to_s
export_dir = project_dir + "Export"
batch_size = 50

puts "exporting " + project_dir + " to " + export_dir

# load project from disk
project = OpenStudio::AnalysisDriver::SimpleProject::open(OpenStudio::Path.new(project_dir)).get

# delete existing export
if File.exists?(export_dir)
  OpenStudio::removeDirectory(OpenStudio::Path.new(export_dir))
end

# export project
Dir.mkdir(export_dir)
# analysis.json
options = OpenStudio::Analysis::AnalysisSerializationOptions.new(project.projectDir)
project.analysis.saveJSON(OpenStudio::Path.new(export_dir + "/analysis.json"),options)
# project.zip
project_zip_file = project.zipFileForCloud
FileUtils.copy_file("#{project_zip_file}", export_dir + "/project.zip")
# data_points_#{batch_index}.json
batch_index = 1
batch = OpenStudio::Analysis::DataPointVector.new
project.analysis.dataPoints.each do |dataPoint|
  if batch.size == 50
    OpenStudio::Analysis::saveJSON(batch,OpenStudio::Path.new(export_dir + "/data_points_#{batch_index}"))
    batch_index += 1
    batch.clear    
  end
  batch << dataPoint
end
if not batch.empty?
  OpenStudio::Analysis::saveJSON(batch,OpenStudio::Path.new(export_dir + "/data_points_#{batch_index}"))
end

