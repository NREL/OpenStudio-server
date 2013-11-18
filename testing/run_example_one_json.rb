# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

HOSTNAME = "http://localhost:8080"
#HOSTNAME = "http://ec2-54-237-92-10.compute-1.amazonaws.com"
WITHOUT_DELAY=false
ANALYSIS_TYPE="batch_run"

formulation_file = "./DiskIOBenchmarkOneJSON/analysis.json"
analysis_zip_file = "./DiskIOBenchmarkOneJSON/analysis.zip"
datapoints_file = "./DiskIOBenchmarkOneJSON/datapoints.json"

options = {hostname: HOSTNAME}
api = OpenStudio::Analysis::ServerApi.new(options)

api.delete_all()

project_options = {}
project_id = api.new_project(project_options)

analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file}
analysis_id = api.new_analysis(project_id, analysis_options)

#api.upload_datapoint(analysis_id)
datapoint_options = {datapoints_file: datapoints_file}
api.upload_datapoints(analysis_id, datapoint_options)

run_options = {analysis_action: "start", without_delay: WITHOUT_DELAY, analysis_type: ANALYSIS_TYPE}
api.run_analysis(analysis_id, run_options)
