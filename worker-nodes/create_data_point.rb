require 'optparse'
require 'fileutils'
require 'uuid'

puts "Parsing Input: #{ARGV}"

# parse arguments with optparse
options = {}
optparse = OptionParser.new do |opts|
  opts.on('-a', '--analysis_id UUID', String, 'UUID of the analysis.') do |analysis_id|
    options[:analysis_id] = analysis_id
  end

  opts.on('-v', '--variables ARRAY', Array, 'Array of variables') do |a|
    options[:variables] = a
  end

end
optparse.parse!

puts "Parsed Input: #{optparse}"

begin
  dp_uuid = UUID.new.generate

  # Load in the Mongo libraries
  libdir = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)
  require 'analysis_chauffeur'

  ros = AnalysisChauffeur.new(dp_uuid)
  ros.log_message "creating new datapoint for analysis with #{options}"
  ros.log_message "new datapoint uuid is #{dp_uuid}"

  dp = DataPoint.find_or_create_by(uuid: dp_uuid)
  dp.name = "Autocreated on worker: #{dp_uuid}"
  dp.analysis_id = options[:analysis_id]
  dp.save!
  sample = {} # {variable_uuid_1: value1, variable_uuid_2: value2}
  options[:variables].each_index do |x_index|
    r_index_value = x_index + 1
    ros.log_message "adding new variable value with r_index #{r_index_value} of value #{options[:variables][x_index]}"

    # todo check for nil variables
    uuid = Variable.where(r_index: r_index_value).first.uuid

    # need to check type of value and convert here
    sample[uuid] = options[:variables][x_index].to_f
  end
  ros.log_message "new variable values are #{sample}"
  dp.set_variable_values = sample
  dp.save!

rescue Exception => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  ros.log_message log_message, true

  # need to tell mongo this failed
  ros.communicate_failure
ensure
  # Must print out a dp uuid of some sort, default is NA
  puts dp ? dp.uuid : 'NA'
end
