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
  opts.banner = 'Usage: ruby api_get_status -h <http://url.org> -d <data_point_id>'
  opts.on('-h', '--host URL', String) { |a| options[:host] = a }
  opts.on('-d', '--data_point_id ID', String) { |a| options[:data_point_id] = a }
end
args = o.order!(ARGV) {}
o.parse!(args)
puts options.inspect

unless options[:host]
  raise 'You must pass the host. e.g. http://localhost:3000'
end

unless options[:data_point_id]
  raise 'You must pass the analysis ID'
end

result = {}
result[:status] = false
begin
  #a = RestClient.get "#{options[:host]}/analyses/#{options[:analysis_id]}/status.json"
  a = RestClient.get "#{options[:host]}/data_points/#{options[:data_point_id]}.json"
  # TODO: retries?
  raise 'Could not create datapoint' unless a.code == 200

  a = JSON.parse(a, symbolize_names: true)
  result[:status] = true
  result[:electricity_cvrmse_within_limit] = a[:data_point][:results][:CalibrationReportsEnhanced21][:electricity_cvrmse_within_limit]
  result[:electricity_nmbe_within_limit] = a[:data_point][:results][:CalibrationReportsEnhanced21][:electricity_nmbe_within_limit]
  result[:natural_gas_cvrmse_within_limit] = a[:data_point][:results][:CalibrationReportsEnhanced21][:natural_gas_cvrmse_within_limit]
  result[:natural_gas_nmbe_within_limit] = a[:data_point][:results][:CalibrationReportsEnhanced21][:natural_gas_nmbe_within_limit]
rescue => e
  puts "#{__FILE__} Error: #{e.message}:#{e.backtrace.join("\n")}"
  result[:status] = false
  result[:electricity_cvrmse_within_limit] = 0
  result[:electricity_nmbe_within_limit] = 0
  result[:natural_gas_cvrmse_within_limit] = 0
  result[:natural_gas_nmbe_within_limit] = 0
ensure
  puts result.to_json
end
