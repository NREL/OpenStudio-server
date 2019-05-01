# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# Simple script that will pass the API requests to the server and wait
# for a response

require 'optparse'
require 'rest-client'

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

  a = RestClient.post "#{options[:host]}/analyses/#{options[:analysis_id]}/data_points.json", data_point_data
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
                a = RestClient.post "#{options[:host]}/data_points/#{datapoint_id}/download_report.json", data_point: { filename: 'objectives' }
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
