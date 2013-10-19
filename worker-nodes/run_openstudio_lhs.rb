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

CRASH_ON_NO_WORKFLOW_VARIABLE = false

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
  @weather_filename = nil

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
        baseline_model_path = File.expand_path(File.join(File.dirname(__FILE__), "..", analysis_json[:analysis]['seed']['path'].split("/").last(2).join("/")))
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

    if analysis_json[:analysis]['weather_file']
      if analysis_json[:analysis]['weather_file']['path']
        @weather_filename = File.expand_path(File.join(File.dirname(__FILE__), "..", analysis_json[:analysis]['weather_file']['path'].split("/").last(4).join("/")))
        if !File.exists?(@weather_filename)
          raise "Could not find weather file for simulation #{@weather_filename}"
        end

      else
        raise "No weather file path defined"
      end
    else
      raise "No weather file block defined"
    end


    # iterate over the workflow and grab the measures
    if analysis_json[:analysis]['problem'] && analysis_json[:analysis]['problem']['workflow'] #ugh i want indifferent access
      analysis_json[:analysis]['problem']['workflow'].each do |wf|

        # process the measure
        measure_path = wf['bcl_measure_directory'].split("/").last(2).first
        measure_name = wf['bcl_measure_class_name_ADDME']

        require "#{File.expand_path(File.join(File.dirname(__FILE__), '..', measure_path, measure_name, 'measure'))}"

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
              ros.log_message data_point_json
              if data_point_json[:data_point]
                if data_point_json[:data_point]['variable_values']
                  if data_point_json[:data_point]['variable_values'][variable_uuid]
                    ros.log_message "Setting variable #{variable_name} to #{data_point_json[:data_point]['variable_values'][variable_uuid]}"
                    v = argument_map[variable_name]
                    raise "Could not find argument map in measure" if not v
                    variable_value = data_point_json[:data_point]['variable_values'][variable_uuid]
                    value_set = v.setValue(variable_value)
                    raise "Could not set variable #{variable_name} of value #{variable_value} on model" unless value_set
                    argument_map[variable_name] = v.clone
                  else
                    raise "Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object" if CRASH_ON_NO_WORKFLOW_VARIABLE
                    ros.log_message("Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object", true)
                    break
                  end
                else
                  raise "No block for variable_values in data point record"
                end
              else
                raise "No block for data_point in data_point record"
              end


              measure.run(@model, runner, argument_map)
              result = runner.result

              ros.log_message result.initialCondition.get.logMessage, true if !result.initialCondition.empty?
              ros.log_message result.finalCondition.get.logMessage, true if !result.finalCondition.empty?

              result.warnings.each { |w| puts w.logMessage }
              result.errors.each { |w| puts w.logMessage }
              result.info.each { |w| puts w.logMessage }

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
  osm_filename = "#{run_directory}/osm_out.osm"
  File.open(osm_filename, 'w') { |f| f << @model.to_s }
  b = Time.now
  ros.log_message "Ruby write took #{b.to_f - a.to_f}", true

  a = Time.now
  @model.save(OpenStudio::Path.new("#{run_directory}/osm_write_out.osm"), true)
  b = Time.now
  ros.log_message "OpenStudio write took #{b.to_f - a.to_f}", true

  ros.log_message "Translate object to energyplus IDF", true
  a = Time.now
  forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new()
  #puts "starting forward translator #{Time.now}"
  @model_idf = forward_translator.translateModel(@model)
  b = Time.now
  ros.log_message "Translate object to energyplus IDF took #{b.to_f - a.to_f}", true

  # Run EnergyPlus using Asset Score run energyplus script
  idf_filename = "#{run_directory}/in.idf"
  File.open(idf_filename, 'w') { |f| f << @model_idf.to_s }

  ros.log_message "Verifying location of Post Process Script", true
  post_process_filename = File.expand_path(File.join(File.dirname(__FILE__), "../..", "post_process.rb"))
  if File.exists?(post_process_filename)
    ros.log_message "Post process file is #{post_process_filename}"
  else
    raise "Could not file post process file #{post_process_filename}"
  end

  ros.log_message "Waiting for simulation to finish", true
  command = "ruby #{run_directory}/run_energyplus.rb -a #{run_directory} -i #{idf_filename} -o #{osm_filename} \
              -w #{@weather_filename} -p #{post_process_filename}"
  #command += " -e #{run_args[:energyplus]}" unless run_args.nil?
  #command += " --idd-path #{run_args[:idd]}" unless run_args.nil?
  #command += " --support-files #{support_files}" unless support_files.nil?
  ros.log_message command, true
  result = `#{command}`

  ros.log_message "Simulation finished", true
  ros.log_message "Simulation results #{result}", true

  # use the completed job to populate data_point with results
  ros.log_message "Updating OpenStudio DataPoint and Communicating Results", true

  # First read in the eplustbl.json file
  if File.exists?("#{run_directory}/run/eplustbl.json")
    result_json = JSON.parse(File.read("#{run_directory}/run/eplustbl.json"), :symbolize_names => true)

    #map the result json back to a flat array
    ros.communicate_results_json(result_json, run_directory)
  end

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

