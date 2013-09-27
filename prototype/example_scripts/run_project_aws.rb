require 'openstudio'

OpenStudio::Logger::instance.standardOutLogger.enable
OpenStudio::Logger::instance.standardOutLogger.setLogLevel(OpenStudio::Info)

project_dir = File.dirname(__FILE__) + '/../pat/PATTest'

# override instance types here or leave nil to use default
serverInstanceType = 't1.micro'
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
    
provider = OpenStudio::AWSProvider.new
provider.setSettings(settings)
if serverInstanceType
  provider.setServerInstanceType(serverInstanceType)
end
if workerInstanceType
  provider.setWorkerInstanceType(workerInstanceType)
end

# test that it is working
puts "userAgreementSigned = #{settings.userAgreementSigned}"
puts "internetAvailable = #{provider.internetAvailable}"
puts "serviceAvailable = #{provider.serviceAvailable}"
puts "validateCredentials = #{provider.validateCredentials}"
puts "resourcesAvailableToStart = #{provider.resourcesAvailableToStart}"

success = provider.requestStartServer

puts "Starting Server success = #{success}"

#success = provider.requestStartWorkers

#puts "Starting Workers success = #{success}"

# DLM: Alex this doesn't seem to work?
success = provider.waitForServer(120000)

puts "Server Started success = #{success}"
puts "Server running = #{provider.serverRunning}"

#provider.waitForWorkers

#puts "Worker Started"

session = provider.session

puts "serverUrl = #{session.serverUrl.get}"

# delete all projects on the server
server = OpenStudio::OSServer.new(session.serverUrl.get)
server.projectUUIDs.each do |projectUUID|
  puts "Deleting project #{projectUUID}"
  success = server.deleteProject(projectUUID)
  puts "  Success = #{success}"
end


# run the project. sets the run type of each data point to CloudDetailed if true
if getDetailedResults
  project.analysis.dataPointsToQueue.each { |data_point|
    data_point.setRunType("CloudDetailed".to_DataPointRunType)
  }
end

driver = OpenStudio::AnalysisDriver::CloudAnalysisDriver.new(provider.session, project)

puts "Starting run"

driver.run

puts "Run finished"
