# call this script with path your OpenStudio install/build
# ruby -I \working\openstudio\build\OpenStudioCore-prefix\src\OpenStudioCore-build\ruby\Debug osserver_test.rb 

# if you want to clean the server before running, ssh into the server and do:
# cd /var/www/rails/openstudio/
# rake db:purge
# rake db:reseed

require 'openstudio'

OpenStudio::Application::instance

# create the vagrant provider
serverPath = OpenStudio::Path.new('C:\working\openstudio-server\vagrant\server')
serverUrl = OpenStudio::Url.new("http://localhost:8080")
workerPath = OpenStudio::Path.new('C:\working\openstudio-server\vagrant\worker')
workerUrl = OpenStudio::Url.new("http://localhost:8081")
haltOnStop = false
vagrantProvider = OpenStudio::VagrantProvider.new(serverPath, serverUrl, workerPath, workerUrl, haltOnStop)

# test that it is working
vagrantProvider.signUserAgreement(true)
puts "userAgreementSigned = #{vagrantProvider.userAgreementSigned}"
puts "internetAvailable = #{vagrantProvider.internetAvailable}"
puts "serviceAvailable = #{vagrantProvider.serviceAvailable}"

# start the server
vagrantProvider.startServer

puts "server starting"

while (vagrantProvider.serverUrl.empty?)
  OpenStudio::System::msleep(3000)
  puts "waiting to boot server"
end

puts "server started"

puts "workers starting"

# start the workers
# TODO: point worker to server?
vagrantProvider.startWorkers

while (vagrantProvider.workerUrls.empty?)
  OpenStudio::System::msleep(3000)
  puts "waiting to boot workers"
end

puts "workers started"

# TODO: how to tell when worker is ready?

# create an OSServer to talk with the server
server = OpenStudio::OSServer.new(vagrantProvider.serverUrl.get)

while (not server.available)
  OpenStudio::System::msleep(3000)
  puts "waiting for server to start"
end

puts "server available"

# read current contents of server database 
projectUUIDs = server.projectUUIDs
puts "projectUUIDs = #{projectUUIDs}"

projectUUIDs.each do |projectUUID|
  puts "Project = #{projectUUID}"

  analysisUUIDs = server.analysisUUIDs(projectUUID)
  puts "#{analysisUUIDs.size} Analyses"
  
  analysisUUIDs.each do |analysisUUID|
    puts "  Analysis = #{analysisUUID}"
    
    dataPointUUIDs = server.dataPointUUIDs(analysisUUID)
    puts "  #{dataPointUUIDs.size} DataPoints"
    
    dataPointUUIDs.each do |dataPointUUID|
      puts "    DataPoint = #{dataPointUUID}"
      
      dataPointJSON = server.dataPointJSON(analysisUUID, dataPointUUID)
      puts "    #{dataPointJSON}"
      
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

# TODO: server.postAnalysisJSON(projectUUID, analysisJSON)

# TODO: server.postDataPointJSON(analysisUUID, dataPointJSON)

# TODO: server.uploadAnalysisFiles(analysisUUID, analysisZipFile)

# TODO: server.start(analysisUUID)

# TODO: server.isAnalysisRunning(analysisUUID)

# TODO: server.stop(analysisUUID)
    
# shut the vagrant boxes down
puts "shutting down"

vagrantProvider.terminate

while (not vagrantProvider.terminateComplete)
  OpenStudio::System::msleep(3000)
  puts "waiting to shut down"
end

puts "goodbye"