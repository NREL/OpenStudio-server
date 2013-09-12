# call this script with path your OpenStudio install/build
# ruby -I \working\openstudio\build\OpenStudioCore-prefix\src\OpenStudioCore-build\ruby\Debug osserver_test.rb 

# if you want to clean the server before running, ssh into the server and do:
# cd /var/www/rails/openstudio/
# rake db:purge
# rake db:reseed

require 'openstudio'

# find paths
serverFileName = File.dirname(__FILE__) + "/../../vagrant/server"
workerFileName = File.dirname(__FILE__) + "/../../vagrant/worker"
patDirName = File.dirname(__FILE__) + "/../pat/PATTest/"

# configuration
serverPath = OpenStudio::Path.new(serverFileName)
serverUrl = OpenStudio::Url.new("http://localhost:8080")
workerPath = OpenStudio::Path.new(workerFileName)
workerUrl = OpenStudio::Url.new("http://localhost:8081")

# call vagrant halt on terminate to simulate longer boot timess
haltOnStop = false

# run the existing project or delete it and create new one
runExisting = false

def listProjects(server)

  projectUUIDs = server.projectUUIDs
  puts "projectUUIDs = #{projectUUIDs}"

  projectUUIDs.each do |projectUUID|
    puts "Project = #{projectUUID}"

    analysisUUIDs = server.analysisUUIDs(projectUUID)
    puts "  Project has #{analysisUUIDs.size} Analyses"
    
    analysisUUIDs.each do |analysisUUID|
      puts "  Analysis = #{analysisUUID}"
      
      dataPointUUIDs = server.dataPointUUIDs(analysisUUID)
      puts "    Analysis has #{dataPointUUIDs.size} DataPoints"
      
      dataPointUUIDs.each do |dataPointUUID|
        puts "    DataPoint = #{dataPointUUID}"
        
        dataPointJSON = server.dataPointJSON(analysisUUID, dataPointUUID)
        puts "      JSON has #{dataPointJSON.size} characters"
        
        # DLM: Nick I don't see the example API call for this, does it exist?
        #TODO: server.downloadDataPoint(analysisUUID, dataPointUUID, downloadPath)
      end
      
      runningDataPointUUIDs = server.runningDataPointUUIDs(analysisUUID)
      puts "  #{runningDataPointUUIDs.size} Running DataPoints"

      queuedDataPointUUIDs = server.queuedDataPointUUIDs(analysisUUID)
      puts "  #{queuedDataPointUUIDs.size} Queued DataPoints"

      completeDataPointUUIDs = server.completeDataPointUUIDs(analysisUUID)
      puts "  #{completeDataPointUUIDs.size} Complete DataPoints"    
    end
  end

end

# create the vagrant provider
settings = OpenStudio::VagrantSettings.new()
settings.setServerPath(serverPath)
settings.setServerUrl(serverUrl)
settings.setWorkerPath(workerPath)
settings.setWorkerUrl(workerUrl)
settings.setHaltOnStop(haltOnStop)

vagrantProvider = OpenStudio::VagrantProvider.new()
vagrantProvider.setSettings(settings)

# test that it is working
settings.signUserAgreement(true)
puts "userAgreementSigned = #{settings.userAgreementSigned}"
puts "internetAvailable = #{vagrantProvider.internetAvailable}"
puts "serviceAvailable = #{vagrantProvider.serviceAvailable}"

# start the server
vagrantProvider.requestStartServer

puts "server starting"

vagrantProvider.waitForServer
if not vagrantProvider.serverStarted
  raise "Could not start server"
end

puts "server started"

# start the workers
vagrantProvider.requestStartWorkers

puts "workers starting"

vagrantProvider.waitForWorkers
if not vagrantProvider.workersStarted
  raise "Could not start workers"
end

puts "workers started"

# create an OSServer to talk with the server
session = vagrantProvider.session
server = OpenStudio::OSServer.new(session.serverUrl.get)

while (not server.available)
  OpenStudio::System::msleep(3000)
  puts "waiting for server to start"
end

puts "server available"

# list projects on the server
listProjects(server)

# the analysis to run
analysisUUID = nil

if runExisting

  # run the first analysis we find
  server.projectUUIDs.each do |projectUUID|
    analysisUUIDs = server.analysisUUIDs(projectUUID)
    analysisUUID = analysisUUIDs[0]
    break
  end
     
else

  # delete all projects on the server
  server.projectUUIDs.each do |projectUUID|
    puts "Deleting project #{projectUUID}"
    success = server.deleteProject(projectUUID)
    puts "  Success = #{success}"
  end

  # list projects on the server
  listProjects(server)

  # load project from disk
  project = OpenStudio::AnalysisDriver::SimpleProject::open(OpenStudio::Path.new(patDirName)).get()
  analysis = project.analysis
  analysisUUID = analysis.uuid()

  # post analysis
  puts "Creating Project #{analysisUUID}"
  success = server.createProject(analysisUUID)
  puts "  Success = #{success}"

  options = OpenStudio::Analysis::AnalysisSerializationOptions.new(OpenStudio::Path.new(patDirName))
  analysisJSON = analysis.toJSON(options)

  puts "Posting Analysis #{analysisUUID}"
  success = server.postAnalysisJSON(analysisUUID, analysisJSON)
  puts "  Success = #{success}"

  File.open(patDirName + "analysisJSON.json", 'w') do |file|
    file << analysisJSON
  end

  analysis.dataPoints().each do |dataPoint|
    options = OpenStudio::Analysis::DataPointSerializationOptions.new(OpenStudio::Path.new(patDirName))
    dataPointJSON = dataPoint.toJSON(options)
    
    puts "Posting DataPoint #{dataPoint.uuid()}"
    success = server.postDataPointJSON(analysisUUID, dataPointJSON)
    puts "  Success = #{success}"
  end

  analysisZipFile = project.zipFileForCloud()

  puts "Uploading analysisZipFile #{analysisZipFile}"
  success = server.uploadAnalysisFiles(analysisUUID, analysisZipFile)
  puts "  Success = #{success}"

  # list projects on the server
  listProjects(server)

end

# start the analysis
puts "Starting analysis #{analysisUUID}"
success = server.start(analysisUUID)
puts "  Success = #{success}"

# list projects on the server
listProjects(server)
  
isQueued = server.isAnalysisQueued(analysisUUID)
puts "isQueued = #{isQueued}"

# todo: wait for running 
 
isRunning = server.isAnalysisRunning(analysisUUID)
puts "isRunning = #{isRunning}"

puts "Stopping analysis #{analysisUUID}"
success = server.stop(analysisUUID)
puts "  Success = #{success}"
  
# shut the vagrant boxes down
vagrantProvider.requestTerminate

puts "shutting down"

if not vagrantProvider.waitForTerminated
  raise "Could not shut down instances"
end

puts "goodbye"