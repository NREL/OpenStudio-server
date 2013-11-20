require 'optparse'
require 'fileutils'
require 'uuid'

puts "Parsing Input: #{ARGV}"

# parse arguments with optparse
options = Hash.new
optparse = OptionParser.new do |opts|
  opts.on('-a', '--analysis_id UUID', String, "UUID of the analysis.") do |analysis_id|
    options[:analysis_id] = analysis_id
  end

  opts.on('-v', '--variables ARRAY', Array, "Array of variables") do |a|
    options[:variables] = a
  end

end
optparse.parse!

puts "Parsed Input: #{optparse}"

puts "Checking Arguments"
if not options[:uuid]
  # required argument is missing
  puts optparse
  exit
end


begin

  time = Time.new
  dp_name = UUID.new.generate
  dp = DataPoint.new({name: dp_name, analysis_id: analysis_id})
  sample = [] # {variable_uuid_1: value1, variable_uuid_2: value2}
  options[:variables].each_index do |x_index|
    uuid = Variables.where(:r_index => x_index).first.uuid
    sample << {uuid: options[:variables][x_index]}
  end
  dp.set_variable_values = sample
  dp.save!
  
  Rails.logger.info("Generated datapoint #{dp.name} for analysis #{@analysis.name}")

  puts dp.uuid
end

