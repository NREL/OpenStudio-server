# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

HOSTNAME = "http://localhost:8080"

#HOSTNAME = "http://ec2-107-22-88-62.compute-1.amazonaws.com"
ANALYSIS_TYPE="sequential_search"

#formulation_file = "./DiscreteExample/analysis.json"
#analysis_zip_file = "./DiscreteExample/analysis.zip"

formulation_file = "./SimpleContinuousExample/analysis.json"
analysis_zip_file = "./SimpleContinuousExample/analysis.zip"

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
    without_delay: false,
    analysis_type: "sequential_search",
    allow_multiple_jobs: true,
    use_server_as_worker: false,
    run_data_point_filename: "run_openstudio_workflow.rb",
    problem: {
        random_seed: 1979,
        algorithm: {
            number_of_samples: 4, # to discretize any continuous variables
            max_iterations: 100,
            objective_functions: [
                "total_energy",
                "total_life_cycle_cost"
            ]
        }
    }
}
api.run_analysis(analysis_id, run_options)
