# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Simple script that will return the status of the analysis
require 'optparse'
require 'rest-client'
require 'json'

options = { submit_simulation: false, sleep_time: 5 }
o = OptionParser.new do |opts|
  opts.banner = 'Usage: ruby api_get_status -h <http://url.org> -a <analysis_id>'
  opts.on('-h', '--host URL', String) { |a| options[:host] = a }
  opts.on('-a', '--analysis_id ID', String) { |a| options[:analysis_id] = a }
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

result = {}
result[:status] = false
get_count = 0
begin
  get_count += 1
  a = RestClient.get "#{options[:host]}/analyses/#{options[:analysis_id]}/status.json" , {accept: :json}
  raise 'Could not create datapoint' unless a.code == 200
  puts "#{__FILE__} success! get_count: #{get_count}"
  a = JSON.parse(a, symbolize_names: true)
  result[:status] = true
  result[:result] = a[:analysis][:run_flag]
rescue => e
  sleep(10)
  puts "#{__FILE__} Error: #{e.message}:#{e.backtrace.join("\n")}"
  puts "#{__FILE__} get_count: #{get_count}"
  retry if get_count <= 10
  result[:status] = false
  result[:result] = true
ensure
  puts result.to_json
end
