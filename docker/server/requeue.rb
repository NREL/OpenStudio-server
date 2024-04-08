require 'redis'
require 'json'
require 'net/http'

# Configuration
redis_host = "queue"
redis_port = 6379
current_hostname = `hostname`.strip
redis = Redis.new(host: redis_host, port: redis_port)

def requeue_datapoint(job_args)
  uri = URI("http://web:80/data_points/#{job_args}/requeue")
  puts "REQUEUE: URI #{uri}"
  request = Net::HTTP::Post.new(uri)
  response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(request)
  end
  puts "REQUEUE: Requeued datapoint with UUID #{job_args}. Response: #{response.code} #{response.message}"
rescue => e
  puts "REQUEUE: Failed to requeue datapoint with UUID #{job_args}. Error: #{e.message}"
end

puts "REQUEUE: getting workers"
workers = redis.smembers("resque:workers")
puts "RESQUEUE: found workers: #{workers}"

workers.each do |worker|
  # Focus on workers processing jobs in the "simulations" queue on the current node
  next unless worker.include?(current_hostname) && worker.include?("simulations")
  puts "RESQUEUE: getting worker: #{worker} for #{current_hostname} in queue: simulations"
  working_on = redis.get("resque:worker:#{worker}")
  puts "RESQUEUE: working_on: #{working_on}"
  if working_on
    puts "RESQUEUE: found local worker"
    job_data = JSON.parse(working_on)
    puts "RESQUEUE: job_data: #{job_data}"
    job_class = job_data["payload"]["class"] rescue "Unknown Class"
    job_args = job_data["payload"]["args"][0] rescue nil

    puts "REQUEUE: Worker #{worker} on this node is processing a job of class #{job_class} with args #{job_args}"

    # Make the API call to requeue the datapoint
    puts "REQUEUE: calling requeue_datapoint"
    requeue_datapoint(job_args)
  end
  
  # Extract PID from worker identifier
  pid = worker.split(":")[1]
  puts "REQUEUE: PID: #{pid}"
  # Send KILL signal to gracefully shutdown the worker

  begin
    puts "REQUEUE: Sending KILL signal to worker with PID #{pid}."
    $stdout.flush
    #this marks the worker as failed in the resque database
    #Process.kill('TERM', pid.to_i)
    #puts "REQUEUE: Sent TERM signal to worker with PID #{pid}."
    Process.kill('QUIT', pid.to_i)
    puts "REQUEUE: Sent QUIT signal to worker with PID #{pid}."
    $stdout.flush
  rescue => e
    puts "REQUEUE: Failed to send KILL signal to worker with PID #{pid}. Error: #{e.message}"
    $stdout.flush
  end
end
