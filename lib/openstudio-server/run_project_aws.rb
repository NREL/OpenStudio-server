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

OpenStudio::Logger::instance.standardOutLogger.enable
fileLog = OpenStudio::FileLogSink.new(OpenStudio::Path.new('./run_project_aws.log'))
fileLog.setLogLevel(OpenStudio::Debug)

project_dir = File.dirname(__FILE__) + './pat/PATTest'

# override instance types here or leave nil to use default
serverInstanceType = 'm1.large'
workerInstanceType = 't1.micro'

# number of workers
numWorkers = 1

# do we want to download detailed results
getDetailedResults = true

# if ARGV[0] is path to a directory containing osp we will use that
if not ARGV[0].nil?
  project_dir = ARGV[0]
end

# open the project. the project log should pick up everything.
options = OpenStudio::AnalysisDriver::SimpleProjectOptions.new
options.setLogLevel(-2) # debug
project = OpenStudio::AnalysisDriver::SimpleProject::open(OpenStudio::Path.new(project_dir), options).get

# DLM: this causes script to fail if client OS version > worker OS version
project.updateModels

# DLM: read credentials from Brian's file
accessKey = nil
secretKey = nil
File.open(File.expand_path('~/.aws_secrets'), 'r') do |file|
  while line = file.gets
    if m = /access_key_id:(.*)/.match(line)
      accessKey = m[1].strip
    elsif m = /secret_access_key:(.*)/.match(line)
      secretKey = m[1].strip
    end
  end
end

puts "accessKey = '#{accessKey}'"
puts "secretKey = '#{secretKey}'"

raise "No AWS credentials found" if not accessKey or not secretKey

# create and start the aws provider
settings = OpenStudio::AWSSettings.new
settings.setNumWorkers(numWorkers)
settings.signUserAgreement(true)
settings.setAccessKey(accessKey)
settings.setSecretKey(secretKey)
settings.setRegion("us-east-1")
if serverInstanceType
  settings.setServerInstanceType(serverInstanceType)
end
if workerInstanceType
  settings.setWorkerInstanceType(workerInstanceType)
end
 
provider = OpenStudio::AWSProvider.new
provider.setSettings(settings)

# test that it is working
puts "userAgreementSigned = #{settings.userAgreementSigned}"
puts "internetAvailable = #{provider.internetAvailable}"
puts "serviceAvailable = #{provider.serviceAvailable}"
puts "validateCredentials = #{provider.validateCredentials}"
puts "resourcesAvailableToStart = #{provider.resourcesAvailableToStart}"

success = provider.requestStartServer
puts "Starting Server success = #{success}"
success = provider.waitForServer
puts "Server Started success = #{success}"

success = provider.requestStartWorkers
puts "Starting Workers success = #{success}"
success = provider.waitForWorkers
puts "Worker Started success = #{success}"

session = provider.session.to_AWSSession.get
url = session.serverUrl.get

puts "Server url = #{session.serverUrl.get}"
File.open('./private_key', 'w') do |f|
  f.puts session.privateKey
end

server = OpenStudio::OSServer.new(session.serverUrl.get)
while not server.available
  puts "Waiting for server"
  OpenStudio::System::msleep(3000)
end

puts "Server available"

# delete all projects on the server
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

success = driver.run

if not success
  puts "Restarting run 1"
  success = driver.run
end

if not success
  puts "Restarting run 2"
  success = driver.run
end

if not success
  puts "Run failed"
end
puts "Run finished"

#success = provider.requestTerminate
#puts "Puts terminating instances, success = #{success}"
#success = provider.waitForTerminated
#puts "Terminating instances complete, success = #{success}"