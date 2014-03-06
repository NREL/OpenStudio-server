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

  options[:profile_run] = false
  opts.on("-p", "--profile-run", "Profile the Run OpenStudio Call") do |pr|
    options[:profile_run] = pr
  end

  options[:debug] = false
  opts.on('--debug', "Set the debug flag") do
    options[:debug] = true
  end
end
optparse.parse!

puts "Parsed Input: #{optparse}"

if options[:profile_run]
  require 'ruby-prof'
  RubyProf.start
end

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
  @model_idf = nil
  @weather_filename = nil
  @output_attributes = []
  @report_measures = []

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

        # This last(2) needs to be cleaned up.  Why don't we know the path of the file?
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
        # This last(4) needs to be cleaned up.  Why don't we know the path of the file?
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

        if wf['measure_type'] == "EnergyPlusMeasure"
          # need to forward translate the model before applying this measure
          if @model_idf.nil?
            ros.log_message "Translate object to EnergyPlus IDF in Prep for EnergyPlus Measure", true
            a = Time.now
            forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
            #puts "starting forward translator #{Time.now}"
            @model_idf = forward_translator.translateModel(@model)
            b = Time.now
            ros.log_message "Translate object to energyplus IDF took #{b.to_f - a.to_f}", true
          end
        end

        # process the measure -- TODO grab the relative directory instead of this last(2).first stuff
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

        ros.log_message "iterate over arguments for workflow item #{wf['name']}", true
        if wf['arguments']
          wf['arguments'].each do |wf_arg|
            if wf_arg['value']
              ros.log_message "Setting argument value #{wf_arg['name']} to #{wf_arg['value']}"

              v = argument_map[wf_arg['name']]
              raise "Could not find argument map in measure" if not v
              value_set = v.setValue(wf_arg['value'])
              raise "Could not set argument #{wf_arg['name']} of value #{wf_arg['value']} on model" unless value_set
              argument_map[wf_arg['name']] = v.clone
            else
              raise "Value for argument '#{wf_arg['name']}' not set in argument list" if CRASH_ON_NO_WORKFLOW_VARIABLE
              ros.log_message("Value for argument '#{wf_arg['name']}' not set in argument list therefore will use default", true)
              break
            end
          end
        end

        ros.log_message "iterate over variables for workflow item #{wf['name']}", true
        if wf['variables']
          wf['variables'].each do |wf_var|

            variable_uuid = wf_var['uuid'] # this is what the variable value is set to
            if wf_var['argument']
              variable_name = wf_var['argument']['name']

              # Get the value from the data point json that was set via R / Problem Formulation
              if data_point_json[:data_point]
                if data_point_json[:data_point]['set_variable_values']
                  if data_point_json[:data_point]['set_variable_values'][variable_uuid]
                    ros.log_message "Setting variable #{variable_name} to #{data_point_json[:data_point]['set_variable_values'][variable_uuid]}"
                    v = argument_map[variable_name]
                    raise "Could not find argument map in measure" if not v
                    variable_value = data_point_json[:data_point]['set_variable_values'][variable_uuid]
                    value_set = v.setValue(variable_value)
                    raise "Could not set variable #{variable_name} of value #{variable_value} on model" unless value_set
                    argument_map[variable_name] = v.clone
                  else
                    raise "[ERROR] Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object" if CRASH_ON_NO_WORKFLOW_VARIABLE
                    ros.log_message("[WARNING] Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object", true)
                    break
                  end
                else
                  raise "No block for set_variable_values in data point record"
                end
              else
                raise "No block for data_point in data_point record"
              end
            else
              raise "Variable '#{variable_name}' is defined but no argument is present"
            end
          end
        end

        if wf['measure_type'] == "RubyMeasure"
          measure.run(@model, runner, argument_map)
        elsif wf['measure_type'] == "EnergyPlusMeasure"
          measure.run(@model_idf, runner, argument_map)
        elsif wf['measure_type'] == "ReportingMeasure"
          report_measures << measure
        end
        result = runner.result

        ros.log_message result.initialCondition.get.logMessage, true if !result.initialCondition.empty?
        ros.log_message result.finalCondition.get.logMessage, true if !result.finalCondition.empty?

        result.warnings.each { |w| ros.log_message w.logMessage, true }
        result.errors.each { |w| ros.log_message w.logMessage, true }
        result.info.each { |w| ros.log_message w.logMessage, true }
        result.attributes.each { |att| @output_attributes << att }
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

  # Check if we have an already translated idf because of an energyplus measure (most likely)
  if @model_idf.nil?
    ros.log_message "Translate object to energyplus IDF", true
    a = Time.now
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    #puts "starting forward translator #{Time.now}"
    @model_idf = forward_translator.translateModel(@model)
    b = Time.now
    ros.log_message "Translate object to energyplus IDF took #{b.to_f - a.to_f}", true
  end

  # Run EnergyPlus using run energyplus script
  idf_filename = "#{run_directory}/in.idf"
  File.open(idf_filename, 'w') { |f| f << @model_idf.to_s }
  
  ros.log_message "adding monthly report to energyplus IDF", true
  to_append = File.read(File.join(File.dirname(__FILE__), "monthly_report.rb"))
  File.open(idf_filename, 'a') do |handle|
      handle.puts to_append
  end    

  ros.log_message "Verifying location of Post Process Script", true
  post_process_filename = File.expand_path(File.join(File.dirname(__FILE__), "post_process_monthly.rb"))
  if File.exists?(post_process_filename)
    ros.log_message "Post process file is #{post_process_filename}"
  else
    raise "Could not find post process file #{post_process_filename}"
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

  # If profiling, then go ahead and get the results here.  Note that we are not profiling the 
  # result of saving the json data and pushing the data back to mongo because the "communicate_results_json" method
  # also ZIPs up the folder and we want the results of the performance to also be in ZIP file.
  if options[:profile_run]
    profile_results = RubyProf.stop
    File.open("#{directory.to_s}/profile-graph.html", "w") { |f| RubyProf::GraphHtmlPrinter.new(profile_results).print(f) }
    File.open("#{directory.to_s}/profile-flat.txt", "w") { |f| RubyProf::FlatPrinter.new(profile_results).print(f) }
    File.open("#{directory.to_s}/profile-tree.prof", "w") { |f| RubyProf::CallTreePrinter.new(profile_results).print(f) }
  end
  
  @report_measures.each { |report_measure|
    # run the reporting measures
    
  }

  # Initialize the objective function variable
  objective_functions = {}
  if File.exists?("#{run_directory}/run/eplustbl.json")
    result_json = JSON.parse(File.read("#{run_directory}/run/eplustbl.json"), :symbolize_names => true)
    ros.log_message "Result JSON is: #{result_json}"
    ros.log_message "analysis_json[:analysis]['output_variables']\n"
    ros.log_message "#{analysis_json[:analysis]['output_variables']}"
    ros.log_message "pulling out objective functions", true
    # Save the objective functions to the object for sending back to the simulation executive
    analysis_json[:analysis]['output_variables'].each do |variable|
      # determine which ones are the objective functions (code smell: todo: use enumerator)
      if variable['objective_function']
        ros.log_message "Found objective function for #{variable['name']}", true
        if result_json[variable['name'].to_sym]
          #objective_functions[variable['name']] = result_json[variable['name'].to_sym]
          objective_functions["objective_function_#{variable['objective_function_index'] + 1}"] = result_json[variable['name'].to_sym]
          if variable['objective_function_target']
            ros.log_message "Found objective function target for #{variable['name']}", true
            objective_functions["objective_function_target_#{variable['objective_function_index'] + 1}"] = variable['objective_function_target'].to_f
          end
          if variable['scaling_factor']
            ros.log_message "Found scaling factor for #{variable['name']}", true
            objective_functions["scaling_factor_#{variable['objective_function_index'] + 1}"] = variable['scaling_factor'].to_f
          end          
        else
          #objective_functions[variable['name']] = nil
          objective_functions["objective_function_#{variable['objective_function_index'] + 1}"] = nil
          objective_functions["objective_function_target_#{variable['objective_function_index'] + 1}"] = nil
          objective_functions["scaling_factor_#{variable['objective_function_index'] + 1}"] = nil
        end
      end
    end

    # todo: make sure that the result_json file is a superset of the other variables in the variable list
    ros.log_message "Communicating data back to server"
    # map the result json back to a flat array
    ros.log_message "Result JSON #{result_json}"
    ros.communicate_results_json(result_json, run_directory)
    ros.log_message "After communicate_results_json()"
  end

  # save the objective function results
  obj_fun_file = "#{run_directory}/objectives.json"
  ros.log_message "Saving objective function file #{obj_fun_file}"
  ros.log_message "Objective Function JSON is #{objective_functions}"
  File.rm_f(obj_fun_file) if File.exists?(obj_fun_file)
  File.open(obj_fun_file, 'w') { |f| f << JSON.pretty_generate(objective_functions) }

  # map the objective function results to an array
  obj_function_array = objective_functions.map { |k, v| v }
rescue Exception => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  ros.log_message log_message, true

  # need to tell the system that this failed
  ros.communicate_failure()
ensure
  ros.log_message "#{__FILE__} Completed", true

  obj_function_array ||= ["NA"]

  # Print the objective functions to the screen even though the file is being used right now
  # Note as well that we can't guarantee that the csv format will be in the right order
  puts obj_function_array.join(",")
end

