# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

hostname = ARGV[0] || "http://localhost:8080"

# Initialize the ServerAPI
options = {hostname: hostname}
api = OpenStudio::Analysis::ServerApi.new(options)

api.delete_all()

# === NSGA2 ==

project_options = {:project_name => "Optimizations"}
project_id = api.new_project(project_options)

formulation_file = "./HouseExample/analysis.json"
analysis_zip_file = "./HouseExample/analysis.zip"
analysis_options = {
    formulation_file: formulation_file,
    upload_file: analysis_zip_file,
    reset_uuids: true,
    analysis_name: "NSGA2"
}
analysis_id = api.new_analysis(project_id, analysis_options)

#  Possible NSGA2 algorithm options
#
#generations: 1,   Number of generations
#tourSize: 2,      Size of tournament
#cprob: 0.7,       Crossover probability
#XoverDistIdx: 5,  Crossover distribution index, it can be any nonnegative real number
#mprob: 0.5,       Mutation probability
#MuDistIdx: 10,    Mutation distribution index, it can be any nonnegative real number

run_options = {
    analysis_action: "start",
    without_delay: false,
    allow_multiple_jobs: false,
    analysis_type: "nsga_nrel",
    simulate_data_point_filename: "simulate_data_point.rb",
    run_data_point_filename: "run_openstudio_workflow_monthly.rb",
    problem: {
        algorithm: {
            number_of_samples: 10,
            sample_method: "all_variables",
            generations: 2,
       cprob: 0.9,
       xoverdistidx: 2,
       mudistidx: 2,
            mprob: 0.9,
            objective_functions: [
                "heating_natural_gas",
                "cooling_electricity",
                "interior_equipment_electricity",
                "fans_electricity"
            ]
        }
    }
}
api.run_analysis(analysis_id, run_options)

