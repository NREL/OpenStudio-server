# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

hostname = ARGV[0] || "http://localhost:8080"

# fast models (~10 secs) with pivots
formulation_file = "./SimpleContinuousExample/analysis.json"
analysis_zip_file = "./SimpleContinuousExample/analysis.zip"

# these models are good but take 80+ seconds to run
#formulation_file = "./ContinuousExample/medium_office.json"
#analysis_zip_file = "./ContinuousExample/medium_office.zip"

options = {hostname: hostname}
api = OpenStudio::Analysis::ServerApi.new(options)

api.delete_all()

project_options = {project_name: "LHS Project"}
project_id = api.new_project(project_options)

analysis_options = {
    formulation_file: formulation_file,
    upload_file: analysis_zip_file,
    reset_uuids: true,
    analysis_name: "simple LHS example"
}
analysis_id = api.new_analysis(project_id, analysis_options)

run_options = {
    analysis_action: "start",
    without_delay: true,
    analysis_type: "lhs",
    allow_multiple_jobs: false,
    use_server_as_worker: false,
    problem: {
        random_seed: 1979,
        algorithm: {
            #number_of_samples: 100,
            number_of_samples: 1, # do not set to one -- todo: fix this!
            sample_method: "all_variables"
            #sample_method: "individual_variables"
        }
    }
}

api.run_analysis(analysis_id, run_options)

run_options = {
    analysis_action: "start",
    run_data_point_filename: "run_openstudio_workflow.rb",
    without_delay: false,
    analysis_type: "batch_run"
}
api.run_analysis(analysis_id, run_options)



