# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

HOSTNAME = "http://localhost:8080"

#HOSTNAME = "http://ec2-107-20-82-197.compute-1.amazonaws.com"

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

analysis_options = {
    formulation_file: formulation_file,
    upload_file: analysis_zip_file,
    reset_uuids: true,
    analysis_name: "PAT Export with 8 data points "}
analysis_id = api.new_analysis(project_id, analysis_options)

datapoint_files.each do |dp|
  datapoint_options = {datapoints_file: dp, reset_uuids: true}
  api.upload_datapoints(analysis_id, datapoint_options)
end

run_options = {
    analysis_action: "start", 
    without_delay: false, 
    analysis_type: 'batch_run'}
api.run_analysis(analysis_id, run_options)

# ===== LHS Sample and Run =====
# fast models (~10 secs) with pivots
formulation_file = "./SimpleContinuousExample/analysis.json"
analysis_zip_file = "./SimpleContinuousExample/analysis.zip"

# these models are good but take 80+ seconds to run
#formulation_file = "./ContinuousExample/medium_office.json"
#analysis_zip_file = "./ContinuousExample/medium_office.zip"

options = {hostname: HOSTNAME}
api = OpenStudio::Analysis::ServerApi.new(options)

api.delete_all()

project_options = {}
project_id = api.new_project(project_options)

analysis_options = {
    formulation_file: formulation_file,
    upload_file: analysis_zip_file,
    reset_uuids: true

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
            number_of_samples: 100,
            #number_of_samples: 3,
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
    allow_multiple_jobs: true,
    analysis_type: "batch_run"
}
api.run_analysis(analysis_id, run_options)


# === NSGA2 ==
formulation_file = "./SimpleContinuousExample/analysis.json"
analysis_zip_file = "./SimpleContinuousExample/analysis.zip"

options = {hostname: HOSTNAME}
api = OpenStudio::Analysis::ServerApi.new(options)

#api.delete_all()

project_options = {}
project_id = api.new_project(project_options)

analysis_options = {
    formulation_file: formulation_file,
    upload_file: analysis_zip_file,
    reset_uuids: true
}
analysis_id = api.new_analysis(project_id, analysis_options)

#
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
    allow_multiple_jobs: true,
    analysis_type: "nsga_nrel",
    problem: {
        algorithm: {
            generations: 25
        }
    }
}
api.run_analysis(analysis_id, run_options)

# ===== Sequential Search =====
formulation_file = "./SimpleContinuousExample/analysis.json"
analysis_zip_file = "./SimpleContinuousExample/analysis.zip"

options = {hostname: HOSTNAME}
api = OpenStudio::Analysis::ServerApi.new(options)


#api.delete_all()

project_options = {}
project_id = api.new_project(project_options)

analysis_options = {
    formulation_file: formulation_file,
    upload_file: analysis_zip_file,
    reset_uuids: true
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
