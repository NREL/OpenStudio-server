# generate n number of datapoints with the exact same list of variables
require 'erb'
require 'securerandom'

number_of_instances=64

dir = File.dirname(__FILE__)
dp_tmp_filename = File.join(dir,"datapoint.json.erb")
dp_tmp = ERB.new(File.open(dp_tmp_filename,'r').read)

# blow away all datapoint_XYZ.jsons
Dir.glob("#{dir}/datapoint_*.json").each do |json|
  puts "json #{json} exists--- deleting"
  File.delete(json)
end

(1..number_of_instances).each do |instance|
  outfile = File.join(dir,"datapoint_#{instance}.json")
  @index = instance
  @uuid = SecureRandom.uuid
  @version_uuid = SecureRandom.uuid
  File.open(outfile, 'w') {|f| f << dp_tmp.result }
end

