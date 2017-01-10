#*******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#*******************************************************************************

# Load the gems from your bundle (do bundle install if you haven't already)
require 'rubygems'
require 'bundler/setup'

require 'openstudio-analysis' # Need to install openstudio-analysis gem

project_name = "./PATTestExport"
if not ARGV[0].nil?
  project_name = ARGV[0]
end

# default is vagrant. for aws, pass in address like 'http://ec2-23-20-3-243.compute-1.amazonaws.com'
# (available from AWS console).
HOSTNAME = "http://localhost:8080"
if not ARGV[1].nil?
  HOSTNAME = ARGV[1]
end

WITHOUT_DELAY=false
ANALYSIS_TYPE="batch_run"
STOP_AFTER_N=nil # set to nil if you want them all
# each may contain up to 50 data points

# Project data
formulation_file = "./" + project_name + "/analysis.json"
analysis_zip_file = "./" + project_name + "/project.zip"
datapoint_files = Dir.glob("./" + project_name + "/data_points_*.json").take(STOP_AFTER_N || 2147483647)

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

datapoint_files.each do |dp|
  datapoint_options = {datapoints_file: dp}
  api.upload_datapoints(analysis_id, datapoint_options)
end

run_options = {
    analysis_action: "start",
    without_delay: WITHOUT_DELAY,
    analysis_type: ANALYSIS_TYPE
}
api.run_analysis(analysis_id, run_options)

#api.kill_analysis(analysis_id)

# TODO: Wait for finished so can use outputs in test statements.
