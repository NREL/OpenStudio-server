require 'openstudio'

serverUrl = OpenStudio::Url.new("http://localhost:8080")

server = OpenStudio::OSServer.new(serverUrl)

puts "Available = #{server.available}"

projectUUIDs = server.projectUUIDs
puts "#{projectUUIDs.size} Projects"

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
    end
  end
end