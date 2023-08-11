# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Simple script that will pass the API requests to the server and wait
# for a response

require 'optparse'
require 'rest-client'
require 'json'

options = { submit_simulation: false, sleep_time: 5 }
o = OptionParser.new do |opts|
  opts.banner = 'Usage: ruby api_create_datapoint -h <http://url.org> -a <analysis_id> -v <variables>'
  opts.on('-h', '--host URL', String) { |a| options[:host] = a }
  opts.on('-a', '--analysis_id ID', String) { |a| options[:analysis_id] = a }
  opts.on('-v', '--variables vars', Array) { |a| options[:variables] = a }
  opts.on('-s', '--sleep vars', Integer) { |a| options[:sleep_time] = a }
  opts.on('--submit') { |_a| options[:submit_simulation] = true }
end
args = o.order!(ARGV) {}
o.parse!(args)
puts options.inspect

unless options[:host]
  raise 'You must pass the host. e.g. http://localhost:3000'
end

unless options[:analysis_id]
  raise 'You must pass the analysis ID'
end

unless options[:variables]
  raise 'You must pass the variables'
end

result = { status: false }
begin
  data_point_data = {
    data_point: {
      name: "API Generated #{Time.now}",
      ordered_variable_values: options[:variables]
    }
  }

  a = RestClient.post "#{options[:host]}/analyses/#{options[:analysis_id]}/data_points.json", data_point_data.to_json , {content_type: :json, accept: :json}
  raise 'Could not create datapoint' unless a.code == 201

  a = JSON.parse(a, symbolize_names: true)
  datapoint_id = a[:_id]
  result[:id] = datapoint_id

  if options[:submit_simulation]
    # check the response
    if datapoint_id
      puts 'Datapoint created, submitting to run queue'
      post_count = 0
      post_count_max = 5
      begin
        post_count += 1
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
              if a[:data_point][:status_message] == 'completed normal'
                result[:status] = true

                # load in the objective functions by accessing the objectives file
                # that were uploaded when the datapoint completed
               begin 
                a = RestClient.post "#{options[:host]}/data_points/#{datapoint_id}/download_report.json", data_point: { filename: 'objectives' }
               rescue => e
                puts "error #{e.message}"
                break  #at this point, simulation completed normal, but objectives failed, so dont try again.  break and be done with it.
               end
               
               a = JSON.parse(a, symbolize_names: true)
                # JSON will be form of:
                # {
                #     "objective_function_1": 24.125,
                #     "objective_function_group_1": 1.0,
                #     "objective_function_2": 266.425,
                #     "objective_function_group_2": 2.0
                # }

                if a[:status] == 'error'
                  #return failed instead of false so it doesnt try to retry
                  result[:status] = 'failed'
                  #raise 'No objective functions returned'
                end

                result[:results] = a
                
              elsif a[:data_point][:status_message] == 'datapoint failure'
                result[:status] = 'failed'
              end
              
              break
            end
          end

          sleep options[:sleep_time]
        end
      end
      rescue => e
        retry if post_count <= post_count_max
        raise "Posting of the run.json file failed #{post_count_max} times with error #{e.message}"
      end
    end
  end

rescue => e
  result[:status] = false
  puts "#{__FILE__} Error: #{e.message}:#{e.backtrace.join("\n")}"
ensure
  puts result.to_json
end
