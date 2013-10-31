# generate n number of datapoints with the exact same list of variables
require 'uuid'
require 'erb'
require 'json'

number_of_instances=64

dir = File.dirname(__FILE__)
dp_tmp_filename = File.join(dir,"datapoint.json.erb")
dp_tmp = ERB.new(File.open(dp_tmp_filename,'r').read)

# blow away all datapoint_XYZ.jsons
Dir.glob("#{dir}/datapoint_*.json").each do |json|
  puts "json #{json} exists--- deleting"
  File.delete(json)
end

one_hash = {"data_points"=>[]}
(1..number_of_instances).each do |instance|
  @index = instance
  @uuid = UUID.new.generate
  @version_uuid = UUID.new.generate
  one_hash << JSON.parse(dp_tmp.result)
end
outfile = File.join(dir,"datapoints.json")
File.open(outfile, 'w') {|f| f << JSON.pretty_generate(one_hash) }