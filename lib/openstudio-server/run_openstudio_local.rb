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

# Test the run_openstudio.rb script on a local build of OpenStudio

require 'openstudio'
require 'fileutils'

project_dir = File.dirname(__FILE__) + '../../testing/PATTest'

if not ARGV[0].nil?
  project_dir = ARGV[0]
end

run_dir = project_dir + "_LocalRun"
if File.exists?(run_dir)
  FileUtils.rm_rf(run_dir)
end
FileUtils.mkdir(run_dir)

# open the project and export to run_dir
project = OpenStudio::AnalysisDriver::SimpleProject::open(project_dir).get
project_zip = project.zipFileForCloud
FileUtils.cp(project_zip.to_s,run_dir + "/project.zip")
unzip = OpenStudio::UnzipFile.new(run_dir + "/project.zip")
unzip.extractAllFiles(run_dir)

# create run folder for last DataPoint 
data_point = project.analysis.dataPoints[project.analysis.dataPoints.size-1]
run_dir = run_dir + "/data_point_#{OpenStudio::removeBraces(data_point.uuid)}"
FileUtils.mkdir(run_dir)
dp_json = run_dir + "/data_point_in.json"
data_point.saveJSON(dp_json)

# run_openstudio.rb
worker_library_path = File.dirname(__FILE__) + '/../../worker-nodes'
run_openstudio_path = worker_library_path + '/run_openstudio.rb'
call_str = "#{$OpenStudio_RubyExe} -I'#{$OpenStudio_Dir}' -I'#{worker_library_path}' '#{run_openstudio_path}' -d '#{run_dir}' -u #{OpenStudio::removeBraces(data_point.uuid)} -r Local"
puts call_str
system(call_str)


