require 'openstudio'

require 'fileutils'

serverUrl = OpenStudio::Url.new("http://localhost:8080")
server = OpenStudio::OSServer.new(serverUrl)
patDirName = File.dirname(__FILE__) + '/../pat/BigPATTest'
patExportDirName = File.dirname(__FILE__) + '/../pat/BigPATTestExport'

# if ARGV[0] is path to a directory containing osp we will use that
doExport = true
if not ARGV[0].nil?
  patDirName = ARGV[0]
  doExport = false
end

# delete old downloads
Dir.glob('./datapoint_*.zip').each do |p|
  File.delete(p)
end

server.projectUUIDs.each do |projectUUID|
  puts "Deleting project #{projectUUID}"
  success = server.deleteProject(projectUUID)
  puts "  Success = #{success}"
end

puts "Loading #{patDirName}"

# load project from disk
project = OpenStudio::AnalysisDriver::SimpleProject::open(OpenStudio::Path.new(patDirName)).get()
projectUUID = project.projectDatabase().handle()
analysis = project.analysis
analysisUUID = analysis.uuid()

# post analysis
puts "Creating Project #{projectUUID}"
success = server.createProject(projectUUID)
puts "  Success = #{success}"

options = OpenStudio::Analysis::AnalysisSerializationOptions.new(project.projectDir)
analysisJSON = analysis.toJSON(options)

if doExport
  File.open(patExportDirName + "/analysis.json", 'w') do |file|
    file.puts analysisJSON
  end
end

puts "Posting Analysis #{analysisUUID}"
success = server.postAnalysisJSON(projectUUID, analysisJSON)
puts "  Success = #{success}"

analysis.dataPoints().each do |dataPoint|
  options = OpenStudio::Analysis::DataPointSerializationOptions.new(OpenStudio::Path.new(patDirName))
  dataPointJSON = dataPoint.toJSON(options)
  
  if doExport
    File.open(patExportDirName + "/datapoint_#{dataPoint.uuid().to_s.gsub('}','').gsub('{','')}.json", 'w') do |f|
      f.puts dataPointJSON
    end
  end
  
  puts "Posting DataPoint #{dataPoint.uuid()}"
  success = server.postDataPointJSON(analysisUUID, dataPointJSON)
  puts "  Success = #{success}"
end

analysisZipFile = project.zipFileForCloud()
if doExport
  FileUtils.copy_file("#{analysisZipFile}", patExportDirName + "/analysis.zip")
end
exit
puts "Uploading analysisZipFile #{analysisZipFile}"
success = server.uploadAnalysisFiles(analysisUUID, analysisZipFile)
puts "  Success = #{success}"

# start the analysis
puts "Starting analysis #{analysisUUID}"
success = server.start(analysisUUID)
puts "  Success = #{success}"
  
isRunning = false
while not isRunning
  isQueued = server.isAnalysisQueued(analysisUUID)
  puts "isQueued = #{isQueued}"

  isRunning = server.isAnalysisRunning(analysisUUID)
  puts "isRunning = #{isRunning}"
   
  isComplete = server.isAnalysisComplete(analysisUUID)
  puts "isComplete = #{isComplete}"
  
  queuedDataPointUUIDs = server.queuedDataPointUUIDs(analysisUUID)
  puts "#{queuedDataPointUUIDs.size} Queued DataPoints"

  runningDataPointUUIDs = server.runningDataPointUUIDs(analysisUUID)
  puts "#{runningDataPointUUIDs.size} Running DataPoints"

  completeDataPointUUIDs = server.completeDataPointUUIDs(analysisUUID)
  puts "#{completeDataPointUUIDs.size} Complete DataPoints"    
  
  downloadReadyDataPointUUIDs = server.downloadReadyDataPointUUIDs(analysisUUID)
  puts "#{downloadReadyDataPointUUIDs.size} Download Ready DataPoints"

  puts
  
  OpenStudio::System::msleep(3000)
end

puts "Analysis Started"

isComplete = false
while not isComplete
  isQueued = server.isAnalysisQueued(analysisUUID)
  puts "isQueued = #{isQueued}"
   
  isRunning = server.isAnalysisRunning(analysisUUID)
  puts "isRunning = #{isRunning}"

  isComplete = server.isAnalysisComplete(analysisUUID)
  puts "isComplete = #{isComplete}"

  dataPointUUIDs = server.dataPointUUIDs(analysisUUID)
  puts "#{dataPointUUIDs.size} DataPoints"

  queuedDataPointUUIDs = server.queuedDataPointUUIDs(analysisUUID)
  puts "#{queuedDataPointUUIDs.size} Queued DataPoints"

  runningDataPointUUIDs = server.runningDataPointUUIDs(analysisUUID)
  puts "#{runningDataPointUUIDs.size} Running DataPoints"

  completeDataPointUUIDs = server.completeDataPointUUIDs(analysisUUID)
  puts "#{completeDataPointUUIDs.size} Complete DataPoints"
  
  downloadReadyDataPointUUIDs = server.downloadReadyDataPointUUIDs(analysisUUID)
  puts "#{downloadReadyDataPointUUIDs.size} Download Ready DataPoints"

  puts
  
  OpenStudio::System::msleep(3000)
end

puts "Analysis Completed"

completeDataPointUUIDs = server.completeDataPointUUIDs(analysisUUID)
puts "  #{completeDataPointUUIDs.size} Complete DataPoints"

# try to load the results
completeDataPointUUIDs.each do |dataPointUUID|
  json = server.dataPointJSON(analysisUUID, dataPointUUID)
  result = OpenStudio::Analysis::loadJSON(json)
  if result.analysisObject.empty? or result.analysisObject.get.to_DataPoint.empty?
    puts "Can't reconstruct dataPoint #{dataPointUUID}"
  end
end

downloadReadyDataPointUUIDs = server.downloadReadyDataPointUUIDs(analysisUUID)
puts "  #{downloadReadyDataPointUUIDs.size} Download Ready DataPoints"

# try to download results
downloadReadyDataPointUUIDs.each do |dataPointUUID|
  path = OpenStudio::Path.new("./datapoint_#{dataPointUUID.to_s.gsub('}','').gsub('{','')}.zip")
  result = server.downloadDataPoint(analysisUUID, dataPointUUID, path)
  if not result
    puts "Failed to download dataPoint #{dataPointUUID}"
  end
end

puts "Stopping analysis #{analysisUUID}"
success = server.stop(analysisUUID)
puts "  Success = #{success}"