require 'openstudio'
require 'openstudio/energyplus/find_energyplus'
require 'optparse'
require 'fileutils'


puts "Parsing Input: #{ARGV.inspect}"

# parse arguments with optparse
options = Hash.new
optparse = OptionParser.new do |opts|

  opts.on('-d', '--directory DIRECTORY', String, "Path to the directory will run the Data Point.") do |directory|
    options[:directory] = directory
  end

  opts.on('-u', '--uuid UUID', String, "UUID of the data point to run with no braces.") do |uuid|
    options[:uuid] = uuid
  end

  options[:runType] = "AWS"
  opts.on('-r', '--runType RUNTYPE', String, "String that indicates where Simulate Data Point is being run (Local|AWS).") do |runType|
    options[:runType] = runType
  end

  options[:logLevel] = -1
  opts.on('-l', '--logLevel LOGLEVEL', Integer, "Level of detail for project.log file. Trace = -3, Debug = -2, Info = -1, Warn = 0, Error = 1, Fatal = 2.") do |logLevel|
    options[:logLevel] = logLevel
  end

end
optparse.parse!

puts "Parsed Input: #{optparse}"

puts "Checking Arguments"
if not options[:directory]
  # required argument is missing
  puts optparse
  exit
end

puts "Checking UUID of #{options[:uuid]}"
if (not options[:uuid]) || (options[:uuid] == "NA")
  puts "No UUID defined"
  if options[:uuid] == "NA"
    puts "Recevied an NA UUID which may be because you are only trying to run one datapoint"
  end
  exit
end

require 'analysis_chauffeur'
ros = AnalysisChauffeur.new(options[:uuid])

# let listening processes know that this data point is running
ros.log_message "File #{__FILE__} started executing on #{options[:uuid]}", true
logLevel = options[:logLevel].to_i

run_directory = options[:directory]
ros.log_message "Run directory is #{run_directory}", true
objective_function_result = nil

begin
  # initialize
  @model = nil

  ros.log_message "Getting Problem JSON input", true

  # get json from database
  data_point_json, analysis_json = ros.get_problem("hash")


  ros.log_message "Parsing Analysis JSON input & Applying Measures", true
  # by hand for now, go and get the information about the measures
  if analysis_json && analysis_json[:analysis]
    ros.log_message "Loading baseline model"

    if analysis_json[:analysis]['seed']
      ros.log_message "#{analysis_json[:analysis]['seed']}"

      # Some reason this hash is not indifferent access
      if analysis_json[:analysis]['seed']['path']

        # Not sure that this is always split with last 3
        baseline_model_path = File.expand_path(File.join(File.dirname(__FILE__),"..",analysis_json[:analysis]['seed']['path'].split("/").last(2).join("/")))
        if File.exists?(baseline_model_path)
          ros.log_message "Reading in baseline model #{baseline_model_path}"
          translator = OpenStudio::OSVersion::VersionTranslator.new
          path = OpenStudio::Path.new(File.expand_path(baseline_model_path))
          model = translator.loadModel(path)
          raise "OpenStudio model is empty" if model.empty?
          @model = model.get
        else
          raise "Seed model #{baseline_model_path} did not exist"
        end
      else
        raise "No seed model path in JSON defined"
      end
    else
      raise "No seed model block"
    end

    if analysis_json[:analysis]['problem'] && analysis_json[:analysis]['problem']['workflow']#ugh i want indifferent access
      # iterate over the workflow and grab the measures
      analysis_json[:analysis]['problem']['workflow'].each do |wf|

        # process the measure
        measure_path = wf['bcl_measure_directory'].split("/").last(2).first
        measure_name = wf['bcl_measure_class_name_ADDME']

        require "#{File.expand_path(File.join(File.dirname(__FILE__),'..',measure_path,measure_name,'measure'))}"

        measure = measure_name.constantize.new
        runner = OpenStudio::Ruleset::OSRunner.new

        arguments = measure.arguments(@model)

        # Create argument map and initialize all the arguments
        argument_map = OpenStudio::Ruleset::OSArgumentMap.new
        arguments.each do |v|
          argument_map[v.name] = v.clone
        end

        ros.log_message "iterate over variables for workflow item", true
        if wf['variables']
          wf['variables'].each do |wf_var|

            variable_uuid = wf_var['uuid'] # this is what the variable value is set to
            if wf_var['argument']
              variable_name = wf_var['argument']['name']

              # get the value from the data point
              if data_point_json[:data_point]['values'][variable_uuid]
                ros.log_message "Setting variable #{variable_name} to #{data_point_json[:data_point]['values'][variable_uuid]}"
                v = argument_map[variable_name]
                raise "Could not find argument map in measure" if not v
                value_set = v.setValue(data_point_json[:data_point]['values'][variable_uuid])
                raise "Could not set value on model" unless value_set
                argument_map[variable_name] = v.clone
              else
                raise "Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object"
              end

              measure.run(@model, runner, argument_map)
              result = runner.result

              ros.log_message result.initialCondition.get.logMessage, true if !result.initialCondition.empty?
              ros.log_message result.finalCondition.get.logMessage, true if !result.finalCondition.empty?

              result.warnings.each {|w| puts w.logMessage}
              result.errors.each {|w| puts w.logMessage}
              result.info.each {|w| puts w.logMessage}

              @model
            else
              raise "Variable '#{variable_name}' is defined but no argument is present"
            end
          end
        end

      end
    end
  end

  #ros.log_message @model.to_s
  a = Time.now
  File.open("#{run_directory}/osm_out.osm", 'w') { |f| f << @model.to_s }
  b = Time.now
  ros.log_message "Ruby write took #{b.to_f - a.to_f}"

  a = Time.now
  @model.save(OpenStudio::Path.new("#{run_directory}/osm_write_out.osm"),true)
  b = Time.now
  ros.log_message "OpenStudio write took #{b.to_f - a.to_f}"

  ros.log_message "Creating Run Manager", true


  ros.log_message "Queue RunManager Job", true

  ros.log_message "Waiting for simulation to finish", true

  ros.log_message "Simulation finished", true

  # use the completed job to populate data_point with results
  ros.log_message "Updating OpenStudio DataPoint object", true

  ros.log_message "Communicating Results", true

  # implemented differently for Local vs. Vagrant or AWS
  #ros.communicate_results(data_point, directory)

  # now set the objective function value or values
  objective_function_result = 0
rescue Exception => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  ros.log_message log_message, true

  # need to tell the system that this failed
  ros.communicate_failure()
ensure
  ros.log_message "#{__FILE__} Completed", true

  # DLM: this is where we put the objective functions.  NL: Note that we must return out of this file nicely no matter what.
  objective_function_result ||= "NA"

  puts objective_function_result
end

