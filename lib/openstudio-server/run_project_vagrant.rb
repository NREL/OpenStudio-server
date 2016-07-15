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

require 'openstudio'

project_dir = File.dirname(__FILE__) + '../../testing/PATTest'

# do we want to download detailed results
getDetailedResults = true

# call vagrant halt on terminate to simulate longer boot timess
haltOnStop = false

# if ARGV[0] is path to a directory containing osp we will use that
if not ARGV[0].nil?
  project_dir = ARGV[0]
end

copy_to_dir = nil
if not ARGV[1].nil?
  copy_to_dir = ARGV[1]
end

# number of points to run
n = nil
if not ARGV[2].nil?
  n = ARGV[2].to_i
end

# open the project. the project log should pick up everything.
options = OpenStudio::AnalysisDriver::SimpleProjectOptions.new
options.setLogLevel(-2) # debug
project = OpenStudio::AnalysisDriver::SimpleProject::open(project_dir,options).get

if not copy_to_dir.nil?
  # save project as copy_to_dir, run there instead
  if File.exists?(copy_to_dir)
    OpenStudio::removeDirectory(copy_to_dir)
  end
  project = OpenStudio::AnalysisDriver::saveAs(project,copy_to_dir).get
  project_dir = copy_to_dir
end

# de-select some datapoints
if not n.nil?
  data_points = project.analysis.dataPoints
  for i in n..(data_points.size - 1)
    data_points[i].setSelected(false)
  end
end

# DLM: this causes script to fail if client OS version > worker OS version
project.updateModels

# create and start the vagrant provider. assumes virtual box already running.
settings = OpenStudio::VagrantSettings.new
settings.setServerPath(OpenStudio::Path.new(File.dirname(__FILE__) + '/../../vagrant/server'))
settings.setServerUrl(OpenStudio::Url.new("http://localhost:8080"))
settings.setWorkerPath(OpenStudio::Path.new(File.dirname(__FILE__) + '/../../vagrant/worker'))
settings.setHaltOnStop(haltOnStop)
settings.setUsername("vagrant")
settings.setPassword("vagrant")
settings.signUserAgreement(true)
provider = OpenStudio::VagrantProvider.new
provider.setSettings(settings)

success = provider.requestStartServer
puts "Starting server request success = #{success}"
provider.waitForServer
success = provider.serverRunning
raise "Server is not running." if not success
puts "Server Started"

success = provider.requestStartWorkers
puts "Starting workers request success = #{success}"
provider.waitForWorkers
success = provider.workersRunning
raise "Workers are not running." if not success
puts "Worker Started"

session = provider.session

# delete all projects on the server
raise "Server URL is unavailable." if session.serverUrl.empty?
server = OpenStudio::OSServer.new(session.serverUrl.get)
server.projectUUIDs.each do |projectUUID|
  puts "Deleting project #{projectUUID}"
  success = server.deleteProject(projectUUID)
  puts "  Success = #{success}"
end

# run the project. sets the run type of each datapoint to CloudDetailed if true
if getDetailedResults
  project.analysis.dataPointsToQueue.each { |data_point|
    data_point.setRunType("CloudDetailed".to_DataPointRunType)
  }
end

driver = OpenStudio::AnalysisDriver::CloudAnalysisDriver.new(provider.session, project)

puts "Starting run"

driver.run

puts "Run finished"
