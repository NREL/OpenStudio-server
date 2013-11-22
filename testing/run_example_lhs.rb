# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

HOSTNAME = "http://localhost:8080"

#HOSTNAME = "http://ec2-107-22-88-62.compute-1.amazonaws.com"
WITHOUT_DELAY=true # NOTE that this is for only the LHS portion the batch_run is asynchronous.
ANALYSIS_TYPE="lhs"

formulation_file = "./ContinuousExample/analysis.json"
analysis_zip_file = "./ContinuousExample/analysis.zip"

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

# Run the LHS -- note that this has to run in the foreground until we move the "get datapoints to run"
# inside of the batch_run method
run_options = {
    analysis_action: "start",
    without_delay: true,
    analysis_type: ANALYSIS_TYPE
}
api.run_analysis(analysis_id, run_options)

run_options = {
    analysis_action: "start",
    without_delay: false,
    analysis_type: "batch_run"
}
api.run_analysis(analysis_id, run_options)

#api.kill_analysis(analysis_id)




