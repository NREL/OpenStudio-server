require 'openstudio'

serverUrl = OpenStudio::Url.new("http://localhost:8080")
server = OpenStudio::OSServer.new(serverUrl)
patDirName = 'C:\working\openstudio-server\prototype\pat\PATTest'

server.projectUUIDs.each do |projectUUID|
  puts "Deleting project #{projectUUID}"
  success = server.deleteProject(projectUUID)
  puts "  Success = #{success}"
end

# load project from disk
project = OpenStudio::AnalysisDriver::SimpleProject::open(OpenStudio::Path.new(patDirName)).get()
projectUUID = project.projectDatabase().handle()
analysis = project.analysis
analysisUUID = analysis.uuid()

# post analysis
puts "Creating Project #{projectUUID}"
success = server.createProject(projectUUID)
puts "  Success = #{success}"

options = OpenStudio::Analysis::AnalysisSerializationOptions.new(OpenStudio::Path.new(patDirName))
analysisJSON = analysis.toJSON(options)

File.open('analysisJSON.json', 'w') do |file|
  file.puts analysisJSON
end

puts "Posting Analysis #{analysisUUID}"
success = server.postAnalysisJSON(projectUUID, analysisJSON)
puts "  Success = #{success}"

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

# start the analysis
puts "Starting analysis #{analysisUUID}"
success = server.start(analysisUUID)
puts "  Success = #{success}"
  
isQueued = server.isAnalysisQueued(analysisUUID)
puts "isQueued = #{isQueued}"

# todo: wait for running 
 
isRunning = server.isAnalysisRunning(analysisUUID)
puts "isRunning = #{isRunning}"

dataPointUUIDs = server.dataPointUUIDs(analysisUUID)
puts "#{dataPointUUIDs.size} DataPoints"

runningDataPointUUIDs = server.runningDataPointUUIDs(analysisUUID)
puts "  #{runningDataPointUUIDs.size} Running DataPoints"

queuedDataPointUUIDs = server.queuedDataPointUUIDs(analysisUUID)
puts "  #{queuedDataPointUUIDs.size} Queued DataPoints"

completeDataPointUUIDs = server.completeDataPointUUIDs(analysisUUID)
puts "  #{completeDataPointUUIDs.size} Complete DataPoints"

# try to load the results
dataPointUUIDs.each do |dataPointUUID|
  json = server.dataPointJSON(analysisUUID, dataPointUUID)
  result = OpenStudio::Analysis::loadJSON(json)
  if result.analysisObject.empty? or result.analysisObject.get.to_DataPoint.empty?
    puts "  Can't reconstruct dataPoint #{dataPointUUID}"
  end
  
  path = OpenStudio::Path.new("./#{dataPointUUID}.zip")
  result = server.downloadDataPoint(analysisUUID, dataPointUUID, path)
  if not result
    puts "  Failed to download dataPoint #{dataPointUUID}"
  end
end


# todo: wait for all complete 

puts "Stoping analysis #{analysisUUID}"
success = server.stop(analysisUUID)
puts "  Success = #{success}"