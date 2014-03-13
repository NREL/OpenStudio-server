# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

hostname = ARGV[0] || "http://localhost:8080"

# Initialize the ServerAPI
options = {hostname: hostname}
api = OpenStudio::Analysis::ServerApi.new(options)

api.delete_all()

# ===== Disk IO Benchmark - Using PAT JSON Files=====
project_options = {:project_name => "PAT Export"}
project_id = api.new_project(project_options)
formulation_file = "./PATTestExport/analysis.json"
analysis_zip_file = "./PATTestExport/project.zip"
datapoint_files = Dir.glob("./PATTestExport/data_points_*.json")

analysis_options = {
    formulation_file: formulation_file,
    upload_file: analysis_zip_file,
    reset_uuids: true,
    analysis_name: "PAT Export with 8 data points"
}
analysis_id = api.new_analysis(project_id, analysis_options)

datapoint_files.each do |dp|
  datapoint_options = {datapoints_file: dp, reset_uuids: true}
  api.upload_datapoints(analysis_id, datapoint_options)
end

run_options = {
    analysis_action: "start",
    without_delay: false,
    use_server_as_worker: true,
    analysis_type: 'batch_run'}
api.run_analysis(analysis_id, run_options)

