require 'openstudio'
require 'fileutils'

# set up log file
logSink = OpenStudio::FileLogSink.new(OpenStudio::Path.new(File.dirname(__FILE__) + "/pat_to_json.log"))
logSink.setLogLevel(-2)
OpenStudio::Logger::instance.standardOutLogger.disable

# Client-side process.
# 1. Open example project
OpenStudio::Application::instance::application
pat_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/PATTest")
project = OpenStudio::AnalysisDriver::SimpleProject::open(pat_path).get
analysis = project.analysis
# X. Create staging folder for mimicking post
staging_dir = OpenStudio::Path.new(File.dirname(__FILE__) + "/staging")
if File.exist?(staging_dir.to_s)
  FileUtils.rm_rf(staging_dir.to_s)
end
FileUtils.mkdir(staging_dir.to_s)
# 2. Create and *post* analysis json file
staged_analysis_json = staging_dir / OpenStudio::Path.new("formulation.json")
analysis.saveJSON(staged_analysis_json,
                  OpenStudio::Analysis::AnalysisSerializationOptions.new(project.projectDir))
# 3. Create and *post* project zip file
zip_local_path = project.zipFileForCloud
staged_zip_file = staging_dir / OpenStudio::Path.new(zip_local_path.filename)
FileUtils.copy_file(zip_local_path.to_s, (staged_zip_file).to_s)

# Server-side process.
# 1. Read json to retrieve analysis UUID.
loaded_json = OpenStudio::Analysis::loadJSON(staged_analysis_json)
loaded_analysis = loaded_json.analysisObject.get.to_Analysis.get
# Y. Delete existing project folder
project_dir_name = "analysis"
if File.exist?(project_dir_name)
  FileUtils.rm_rf(project_dir_name)
end
# 2. Create project folder
FileUtils.mkdir(project_dir_name)
project_dir_path = OpenStudio::completeAndNormalize(OpenStudio::Path.new(project_dir_name))
# 3. Unzip project in folder
unzip = OpenStudio::UnzipFile.new(staged_zip_file)
unzip.extractAllFiles(project_dir_path) # formulation.json is in here too.
# 4. Fix up paths in formulation.json
loaded_analysis.updateInputPathData(loaded_json.projectDir, project_dir_path)
analysis_options = OpenStudio::Analysis::AnalysisSerializationOptions.new(project_dir_path)
loaded_analysis.saveJSON(project_dir_path / OpenStudio::Path.new("formulation.json"), analysis_options, true)

# Client-side process.
# 1. Create and *post* data point requests
analysis.dataPoints.each { |data_point|
  staged_data_point_json = staging_dir /
      OpenStudio::Path.new("data_point_in." +
                               OpenStudio::removeBraces(data_point.uuid) +
                               ".json")
  data_point.saveJSON(staged_data_point_json,
                      OpenStudio::Analysis::DataPointSerializationOptions.new(project.projectDir))
}

# Server-side process. 
Dir.glob(staging_dir.to_s + "/data_point_in.*.json").each { |dp_file|
  # 1. Read json to retrieve data point UUID
  loaded_json = OpenStudio::Analysis::loadJSON(OpenStudio::Path.new(dp_file))
  loaded_data_point = loaded_json.analysisObject.get.to_DataPoint.get
  # 2. Create data point folder
  data_point_dir_name = "data_point_" + OpenStudio::removeBraces(loaded_data_point.uuid)
  data_point_dir_path = project_dir_path / OpenStudio::Path.new(data_point_dir_name)
  FileUtils.mkdir(data_point_dir_path.to_s)
  # 3. Copy json into folder
  FileUtils.copy_file(dp_file, (data_point_dir_path / OpenStudio::Path.new("data_point_in.json")).to_s)
}
