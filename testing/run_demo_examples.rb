# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

HOSTNAME = "http://localhost:8080"
                              #HOSTNAME = "http://ec2-67-202-41-219.compute-1.amazonaws.com/"

                              # Initialize the ServerAPI
options = {hostname: HOSTNAME}
api = OpenStudio::Analysis::ServerApi.new(options)

api.delete_all()

project_options = {}
project_id = api.new_project(project_options)

# ===== Disk IO Benchmark - Using PAT JSON Files=====
formulation_file = "./PATTestExport/analysis.json"
analysis_zip_file = "./PATTestExport/project.zip"
datapoint_files = Dir.glob("./PATTestExport/data_points_*.json")

analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file,
                    reset_uuids: true, analysis_name: "PAT Export with 8 data points "}
analysis_id = api.new_analysis(project_id, analysis_options)

datapoint_files.each do |dp|
  datapoint_options = {datapoints_file: dp, reset_uuids: true}
  api.upload_datapoints(analysis_id, datapoint_options)
end

run_options = {analysis_action: "start", without_delay: false, analysis_type: 'batch_run'}
api.run_analysis(analysis_id, run_options)

# ===== LHS Sample and Run =====
formulation_file = "./ContinuousExample/analysis.json"
analysis_zip_file = "./ContinuousExample/analysis.zip"

analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file,
                    reset_uuids: true, analysis_name: "LHS Sample and Run"}
analysis_id = api.new_analysis(project_id, analysis_options)

run_options = {analysis_action: "start", without_delay: false, analysis_type: "lhs", allow_multiple_jobs: true}
api.run_analysis(analysis_id, run_options)

run_options = {
    analysis_action: "start",
    without_delay: false,
    analysis_type: "batch_run",
    allow_multiple_jobs: true,
    use_server_as_worker: false,
    run_data_point_filename: "run_openstudio_workflow.rb"
}
api.run_analysis(analysis_id, run_options)

# ===== Sequential Search =====
formulation_file = "./DiscreteExample/analysis.json"
analysis_zip_file = "./DiscreteExample/analysis.zip"

analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file, reset_uuids: true, analysis_name: "Sequential Search"}
analysis_id = api.new_analysis(project_id, analysis_options)

run_options = {
    analysis_action: "start",
    without_delay: false,
    analysis_type: "sequential_search",
    x_objective_function: "total_energy",
    y_objective_function: "total_life_cycle_cost",
    allow_multiple_jobs: true,
    use_server_as_worker: false,
    run_data_point_filename: "run_openstudio_workflow.rb",
    max_iterations: 3
}
api.run_analysis(analysis_id, run_options)
