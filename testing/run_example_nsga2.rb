# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

HOSTNAME = "http://localhost:8080"

#HOSTNAME = "http://ec2-23-20-3-243.compute-1.amazonaws.com"
WITHOUT_DELAY=false
ANALYSIS_TYPE="NSGA2NREL"
STOP_AFTER_N=nil # set to nil if you want them all
# each may contain up to 50 data points

formulation_file = "./ContinuousExample/medium_office.json"
analysis_zip_file = "./ContinuousExample/medium_office.zip"

options = {hostname: HOSTNAME}
api = OpenStudio::Analysis::ServerApi.new(options)

api.delete_all()

project_options = {}
project_id = api.new_project(project_options)

analysis_options = {
    formulation_file: formulation_file,
    upload_file: analysis_zip_file
}
analysis_id = api.new_analysis(project_id, analysis_options)

run_options = {
    analysis_action: "start",
    without_delay: true,
    analysis_type: ANALYSIS_TYPE
}
api.run_analysis(analysis_id, run_options)





