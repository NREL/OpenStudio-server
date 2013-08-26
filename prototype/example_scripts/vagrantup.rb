require 'openstudio'

OpenStudio::Application::instance

serverPath = OpenStudio::Path.new('C:\working\openstudio-server\vagrant\server')
serverUrl = OpenStudio::Url.new("http://localhost:8080")
workerPath = OpenStudio::Path.new('C:\working\openstudio-server\vagrant\worker')
workerUrl = OpenStudio::Url.new("http://localhost:8081")

vagrantProvider = OpenStudio::VagrantProvider.new(serverPath, serverUrl, workerPath, workerUrl)

vagrantProvider.signUserAgreement(true)

vagrantProvider.internetAvailable

vagrantProvider.serviceAvailable

vagrantProvider.startServer

#vagrantProvider.startWorkers

puts "starting"

while (vagrantProvider.serverUrl.empty?)
  OpenStudio::System::msleep(3000)
  puts "waiting to boot"
end

puts "started"

server = OpenStudio::OSServer.new(vagrantProvider.serverUrl.get)

while (not server.available)
  OpenStudio::System::msleep(3000)
  puts "waiting for server to start"
end

puts "server available"

puts server.projectUUIDs

puts "shutting down"

vagrantProvider.terminate

while (not vagrantProvider.terminateComplete)
  OpenStudio::System::msleep(3000)
  puts "waiting to shut down"
end

puts "goodbye"