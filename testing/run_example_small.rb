# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

HOSTNAME = "http://localhost:8080"
#HOSTNAME = "http://ec2-107-22-88-62.compute-1.amazonaws.com"
WITHOUT_DELAY=false
ANALYSIS_TYPE="batch_run"
STOP_AFTER_N=1  #set to nil if you want them all

# Project data
formulation_file = "./SmallTest/analysis.json"
analysis_zip_file = "./SmallTest/analysis.zip"
datapoint_files = Dir.glob("./SmallTest/data_point*/data_point_in.json").take(STOP_AFTER_N || 2147483647)

options = {hostname: HOSTNAME}
api = ServerApi.new(options)

api.delete_all()

project_options = {}
project_id = api.new_project(project_options)

analysis_options = {formulation_file: formulation_file, upload_file: analysis_zip_file}
analysis_id = api.new_analysis(project_id, analysis_options)

datapoint_files.each do |dp|
  datapoint_options = {datapoint_file: dp}
  api.upload_datapoint(analysis_id, datapoint_options)
end

run_options = {analysis_action: "start", without_delay: WITHOUT_DELAY, analysis_type: ANALYSIS_TYPE}
api.run_analysis(analysis_id, run_options)
