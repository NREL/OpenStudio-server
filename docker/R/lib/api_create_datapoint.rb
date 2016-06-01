# Simple script that will pass the API requests to the server and wait
# for a response

require 'optparse'
require 'rest-client'

options = {submit_simulation: false, sleep_time: 5}
o = OptionParser.new do |opts|
  opts.banner = 'Usage: ruby api_create_datapoint -h <http://url.org> -a <analysis_id> -v <variables>'
  opts.on('-h', '--host URL', String) { |a| options[:host] = a }
  opts.on('-a', '--analysis_id ID', String) { |a| options[:analysis_id] = a }
  opts.on('-v', '--variables vars', Array) { |a| options[:variables] = a }
  opts.on('-s', '--sleep vars', Integer) { |a| options[:sleep_time] = a }
  opts.on('--submit') { |a| options[:submit_simulation] = true }
end
args = o.order!(ARGV) {}
o.parse!(args)
puts options.inspect

unless options[:host]
  fail 'You must pass the host. e.g. http://localhost:3000'
end

unless options[:analysis_id]
  fail 'You must pass the analysis ID'
end

unless options[:variables]
  fail 'You must pass the variables'
end

result = {status: false}
begin
  data_point_data = {
      data_point: {
          name: "API Generated #{Time.now}",
          ordered_variable_values: options[:variables]
      }
  }

  a = RestClient.post "#{options[:host]}/analyses/#{options[:analysis_id]}/data_points.json", data_point_data
  fail 'Could not create datapoint' unless a.code == 201

  a = JSON.parse(a, symbolize_names: true)
  datapoint_id = a[:_id]
  result[:id] = datapoint_id

  if options[:submit_simulation]
    # check the response
    if datapoint_id
      puts 'Datapoint created, submitting to run queue'

      a = RestClient.put "#{options[:host]}/data_points/#{datapoint_id}/run.json", {}
      a = JSON.parse(a, symbolize_names: true)

      # check to make sure that it was submitted and grab the run id
      if a[:job_id]
        puts 'Simulation was submitted... polling until it is finished'
        loop do
          a = RestClient.get "#{options[:host]}/data_points/#{datapoint_id}.json"
          if a.code == 200
            puts 'Checking result ...'
            a = JSON.parse(a, symbolize_names: true)
            puts "Status is #{a[:data_point][:status]}"
            if a[:data_point][:status] == 'completed'
              result[:status] = true

              # load in the objective functions by accessing the objectives file
              # that were uploaded when the datapoint completed
              a = RestClient.post "#{options[:host]}/data_points/#{datapoint_id}/download_report.json", {data_point: {filename: 'objectives'}}
              a = JSON.parse(a, symbolize_names: true)
              if a[:status] == 'error'
                fail "No objective functions returned"
              end

              result[:results] = a

              break
            end
          end

          sleep options[:sleep_time]
        end
      end
    end
  end

rescue => e
  puts "#{__FILE__} Error: #{e.message}:#{e.backtrace.join("\n")}"
ensure
  puts result.to_json
end
