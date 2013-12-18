# Load the gems from your bundle (do bundle install if you haven't already, bundle update if you need to update)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

HOSTNAME = "http://localhost:8080"

#HOSTNAME = "http://ec2-23-20-3-243.compute-1.amazonaws.com"
WITHOUT_DELAY=false
ANALYSIS_TYPE="rgenoud"
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
#  Possible rgenoud algorithm options
#
#generations: 1,              Number of generations
#waitGenerations=1            If there is no improvement in the objective function in this number of generations, algorithm will terminate
#popSize: 30,                 Population Size
#boundaryEnforcement: 2,      0: Anything Goes, 1: partial enforcement, 2: No trespassing
#printLevel: 2,               0 (minimal printing), 1 (normal), 2 (detailed), and 3 (debug)
#epsilonGradient: 1e-1
#solutionTolerance: 0.001     This is the tolerance level used by genoud.
#balance: false               Load balance the Cluster
#use_server_as_worker: true   Must have server_as_worker set to true

run_options = {
    analysis_action: "start",
    without_delay: false,
    use_server_as_worker: true,
    analysis_type: ANALYSIS_TYPE,
    problem: {
        algorithm: {
            generations: 25,
            epsilonGradient: 1e0,
            balance: true
        }
    }
}
api.run_analysis(analysis_id, run_options)





