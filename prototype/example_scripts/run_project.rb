require 'openstudio'

project_dir = File.dirname(__FILE__) + '/../pat/PATTest'
get_details = false

# if ARGV[0] is path to a directory containing osp we will use that
if not ARGV[0].nil?
  project_dir = ARGV[0]
end

# open the project. the project log should pick up everything.
options = OpenStudio::AnalysisDriver::SimpleProjectOptions.new
options.setLogLevel(-2) # debug
project = OpenStudio::AnalysisProject::SimpleProject::open(project_dir,options).get

# create and start the vagrant provider. assumes virtual box already running.
settings = OpenStudio::VagrantSettings.new
settings.setServerPath(OpenStudio::Path.new(File.dirname(__FILE__) + '../../vagrant/server'))
settings.setServerUrl(OpenStudio::Url.new("http://localhost:8080"))
settings.setWorkerPath(OpenStudio::Path.new(File.dirname(__FILE__) + '../../vagrant/worker'))
settings.setHaltOnStop(true)
settings.setUsername("vagrant")
settings.setPassword("vagrant")
settings.signUserAgreement(true)
provider = OpenStudio::VagrantProvider.new
provider.setSettings(settings)
provider.requestStartServer
provider.waitForServer
provider.requestStartWorkers
provider.waitForWorkers

# run the project. sets the run type of each data point to CloudDetailed if get_details.
if get_details
  project.analysis.dataPointsToQueue.each { |data_point|
    data_point.setRunType("CloudDetailed".to_DataPointRunType)
  }
end
driver = OpenStudio::AnalysisDriver::CloudAnalysisDriver.new(provider.session,project)
driver.run
