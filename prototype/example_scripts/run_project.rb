require 'openstudio'

project_dir = File.dirname(__FILE__) + '/../pat/PATTest'

# do we want to download detailed results
getDetailedResults = false

# call vagrant halt on terminate to simulate longer boot timess
haltOnStop = false

# if ARGV[0] is path to a directory containing osp we will use that
if not ARGV[0].nil?
  project_dir = ARGV[0]
end

# open the project. the project log should pick up everything.
options = OpenStudio::AnalysisDriver::SimpleProjectOptions.new
options.setLogLevel(-2) # debug
project = OpenStudio::AnalysisDriver::SimpleProject::open(OpenStudio::Path.new(project_dir), options).get

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

puts "Starting Server success = #{success}"

success = provider.requestStartWorkers

puts "Starting Worker success = #{success}"

provider.waitForServer

puts "Server Started"

provider.waitForWorkers

puts "Worker Started"

# delete all projects on the server
server = OpenStudio::OSServer.new(settings.serverUrl)
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
