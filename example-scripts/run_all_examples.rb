require './ServerApi.rb'

HOSTNAME = "http://localhost:8080"
#HOSTNAME = "http://ec2-54-237-92-10.compute-1.amazonaws.com"

# Initialize the ServerAPI
options = {hostname: HOSTNAME}
api = ServerApi.new(options)

api.delete_all()

project_options = {}
project_id = api.new_project(project_options)


# ===== Disk IO Benchmark =====
#formulation_file = "./DiskIOBenchmark/analysis.json"
#analysis_zip_file = "./DiskIOBenchmark/analysis.zip"
#datapoint_files = Dir.glob("./DiskIOBenchmark/datapoint*.json").take(2)
#
#analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file,
#                    reset_uuids: true, analysis_name: "DiskIOBenchmark Batch Run 2 - simulations"}
#analysis_id = api.new_analysis(project_id, analysis_options)
#
#datapoint_files.each do |dp|
#  datapoint_options = {datapoint_file: dp, reset_uuids: true}
#  api.upload_datapoint(analysis_id, datapoint_options)
#end
#
#run_options = {analysis_action: "start", without_delay: false, analysis_type: 'batch_run'}
#api.run_analysis(analysis_id, run_options)


# ===== LHS Sample and Run =====
formulation_file = "./ContinuousExample/analysis.json"
analysis_zip_file = "./ContinuousExample/analysis.zip"

analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file,
                    reset_uuids: true, analysis_name: "LHS Sample and Run"}
analysis_id = api.new_analysis(project_id, analysis_options)

# Run the LHS -- note that this has to run in the foreground until we move the "get datapoints to run"
# inside of the batch_run method
run_options = {analysis_action: "start", without_delay: true, analysis_type: "lhs"}
api.run_analysis(analysis_id, run_options)

#run_options = {analysis_action: "start", without_delay: false, analysis_type: "batch_run"}
#api.run_analysis(analysis_id, run_options)

