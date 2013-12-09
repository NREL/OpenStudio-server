# Load the gems from your bundle (do bundle install if you haven't already, bundle update if you need to update)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

HOSTNAME = "http://localhost:8080"

#HOSTNAME = "http://ec2-23-20-3-243.compute-1.amazonaws.com"
WITHOUT_DELAY=false
ANALYSIS_TYPE="nsga_nrel"
STOP_AFTER_N=nil # set to nil if you want them all
# each may contain up to 50 data points

formulation_file = "./SimpleContinuousExample/analysis.json"
analysis_zip_file = "./SimpleContinuousExample/analysis.zip"

options = {hostname: HOSTNAME}
api = OpenStudio::Analysis::ServerApi.new(options)

api.delete_all()

project_options = {}
project_id = api.new_project(project_options)

analysis_options = {
    formulation_file: formulation_file,
    upload_file: analysis_zip_file #,
    #reset_uuids: true,
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
    analysis_type: ANALYSIS_TYPE,
    problem: {
        algorithm: {
            generations: 25
        }
    }
}
api.run_analysis(analysis_id, run_options)





