# generate n number of datapoints with the exact same list of variables
require 'erb'
require 'json'
require 'securerandom'

number_of_instances=64

dir = File.dirname(__FILE__)
dp_tmp_filename = File.join(dir, "datapoint.json.erb")
dp_tmp = ERB.new(File.open(dp_tmp_filename, 'r').read)

# blow away all datapoint_XYZ.jsons
Dir.glob("#{dir}/datapoint_*.json").each do |json|
  puts "json #{json} exists--- deleting"
  File.delete(json)
end

one_hash = {data_points: []}
(1..number_of_instances).each do |instance|
  @index = instance
  @uuid = SecureRandom.uuid
  @version_uuid = UUID.new.generate
  to_add =JSON.parse(dp_tmp.result)["data_point"]
  one_hash[:data_points] << to_add
end
outfile = File.join(dir, "datapoints.json")
File.open(outfile, 'w') { |f| f << JSON.pretty_generate(one_hash) }