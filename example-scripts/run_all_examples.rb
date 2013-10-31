require './ServerApi.rb'

HOSTNAME = "http://localhost:8080"
#HOSTNAME = "http://ec2-54-237-92-10.compute-1.amazonaws.com"

# Initialize the ServerAPI
options = {hostname: HOSTNAME}
api = ServerApi.new(options)

api.delete_all()

project_options = {}
project_id = api.new_project(project_options)

# ===== Disk IO Benchmark - Using PAT JSON Files=====
formulation_file = "./DiskIOBenchmark/analysis.json"
analysis_zip_file = "./DiskIOBenchmark/analysis.zip"
datapoint_files = Dir.glob("./DiskIOBenchmark/datapoint*.json").take(2)

analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file,
                    reset_uuids: true, analysis_name: "DiskIOBenchmark Batch Run Only 2 Simulations"}
analysis_id = api.new_analysis(project_id, analysis_options)

datapoint_files.each do |dp|
  datapoint_options = {datapoint_file: dp, reset_uuids: true}
  api.upload_datapoint(analysis_id, datapoint_options)
end

run_options = {analysis_action: "start", without_delay: false, analysis_type: 'batch_run'}
api.run_analysis(analysis_id, run_options)


## ===== LHS Sample and Run =====
#formulation_file = "./ContinuousExample/analysis.json"
#analysis_zip_file = "./ContinuousExample/analysis.zip"
#
#analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file,
#                    reset_uuids: true, analysis_name: "LHS Sample and Run"}
#analysis_id = api.new_analysis(project_id, analysis_options)
#
#run_options = {analysis_action: "start", without_delay: false, analysis_type: "lhs", allow_multiple_jobs: true}
#api.run_analysis(analysis_id, run_options)
#
#run_options = {analysis_action: "start", without_delay: false, analysis_type: "batch_run", allow_multiple_jobs: true, use_server_as_worker: true, simulate_data_point_filename: "simulate_data_point_lhs.rb"}
#api.run_analysis(analysis_id, run_options)
#
## ===== LHS Sample and Run Number 2 =====
#formulation_file = "./ContinuousExample/analysis.json"
#analysis_zip_file = "./ContinuousExample/analysis.zip"
#
#analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file,
#                    reset_uuids: true, analysis_name: "LHS Sample and Run 2"}
#analysis_id = api.new_analysis(project_id, analysis_options)
#
#run_options = {analysis_action: "start", without_delay: false, analysis_type: "lhs", allow_multiple_jobs: true}
#api.run_analysis(analysis_id, run_options)
#
#run_options = {analysis_action: "start", without_delay: false, analysis_type: "batch_run", allow_multiple_jobs: true, use_server_as_worker: true, simulate_data_point_filename: "simulate_data_point_lhs.rb"}
#api.run_analysis(analysis_id, run_options)
#
#
## ===== Sequential Search =====
#formulation_file = "./ContinuousExample/analysis_discrete.json"
#analysis_zip_file = "./ContinuousExample/analysis.zip"
#
#analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file, reset_uuids: true, analysis_name: "Sequential Search"}
#analysis_id = api.new_analysis(project_id, analysis_options)
#
#run_options = {
#    analysis_action: "start",
#    without_delay: false,
#    analysis_type: "sequential_search",
#    x_objective_function: "total_energy",
#    y_objective_function: "total_life_cycle_cost",
#    allow_multiple_jobs: true,
#    use_server_as_worker: true,
#    simulate_data_point_filename: "simulate_data_point_lhs.rb",
#    max_iterations: 2
#}
#api.run_analysis(analysis_id, run_options)