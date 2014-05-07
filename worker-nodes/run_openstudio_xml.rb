require 'openstudio'
require 'openstudio/energyplus/find_energyplus'
require 'optparse'
require 'fileutils'
require 'libxml'

puts "Parsing Input: #{ARGV.inspect}"

# parse arguments with optparse
options = {}
optparse = OptionParser.new do |opts|

  opts.on('-d', '--directory DIRECTORY', String, 'Path to the directory will run the Data Point.') do |directory|
    options[:directory] = directory
  end

  opts.on('-u', '--uuid UUID', String, 'UUID of the data point to run with no braces.') do |uuid|
    options[:uuid] = uuid
  end

  options[:problem_formulation] = nil
  opts.on('--problem', String, 'Optional problem formulation file which will override value in mongo') do |pr|
    options[:problem_formulation] = pr
  end

  options[:logLevel] = -1
  opts.on('-l', '--logLevel LOGLEVEL', Integer, 'Level of detail for project.log file. Trace = -3, Debug = -2, Info = -1, Warn = 0, Error = 1, Fatal = 2.') do |logLevel|
    options[:logLevel] = logLevel
  end

  options[:profile_run] = false
  opts.on('-p', '--profile-run', 'Profile the Run OpenStudio Call') do |pr|
    options[:profile_run] = pr
  end

  options[:debug] = false
  opts.on('--debug', 'Set the debug flag') do
    options[:debug] = true
  end
end
optparse.parse!

puts "Parsed Input: #{optparse}"

if options[:profile_run]
  require 'ruby-prof'
  RubyProf.start
end

puts 'Checking Arguments'
unless options[:directory]
  # required argument is missing
  puts optparse
  exit
end

puts "Checking UUID of #{options[:uuid]}"
if (not options[:uuid]) || (options[:uuid] == 'NA')
  puts 'No UUID defined'
  if options[:uuid] == 'NA'
    puts 'Recevied an NA UUID which may be because you are only trying to run one datapoint'
  end
  exit
end

CRASH_ON_NO_WORKFLOW_VARIABLE = false

require 'analysis_chauffeur'
ros = AnalysisChauffeur.new(options[:uuid])

def create_osm_from_xml(xml, run_path, weather_path, space_lib_path, logger)
  osm_model = nil

  # TODO move the analysis dir to a general setting
  analysis_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  require "#{analysis_dir}/lib/openstudio_xml/main"

  # Save the final state of the XML file
  xml.save("#{run_path}/final.xml")

  logger.log_message 'Starting XML to OSM translation', true

  osxt = Main.new(weather_path, space_lib_path)
  osm, idf, new_xml, building_name, weather_file = osxt.process(xml.to_s, false, true)
  if osm
    File.open("#{run_path}/xml_out.osm", 'w') { |f| f << osm }

    logger.log_message 'Finished XML to OSM translation', true
  else
    fail 'No OSM model output from XML translation'
  end

  osm
end

# let listening processes know that this data point is running
ros.log_message "File #{__FILE__} started executing on #{options[:uuid]}", true
logLevel = options[:logLevel].to_i

run_directory = options[:directory]
ros.log_message "Run directory is #{run_directory}", true
objective_function_result = nil

begin
  # initialize
  @xml_model = nil
  @model = nil
  @model_idf = nil
  @weather_filename = nil
  @output_attributes = []
  @report_measures = []
  @space_lib_path = File.expand_path(File.join(File.dirname(__FILE__), '../lib/openstudio_xml/space_types'))

  ros.log_message "Space Type Library set to #{@space_lib_path}"

  ros.log_message 'Getting Problem JSON input', true

  # get json from database
  data_point_json, analysis_json = ros.get_problem('hash')

  ros.log_message 'Parsing Analysis JSON input & Applying Measures', true
  # by hand for now, go and get the information about the measures
  if analysis_json && analysis_json[:analysis]
    ros.log_message 'Loading baseline model'

    if analysis_json[:analysis]['seed']
      ros.log_message "#{analysis_json[:analysis]['seed']}"

      # Some reason this hash is not indifferent access
      if analysis_json[:analysis]['seed']['path']

        # The seed path is relative to the run directory for the XML case
        xml_baseline = File.expand_path(File.join(File.dirname(__FILE__), '..', analysis_json[:analysis]['seed']['path']))
        if File.exist?(xml_baseline)
          ros.log_message "Reading in baseline model #{xml_baseline}"
          @xml_model = LibXML::XML::Document.file(xml_baseline)
          fail 'XML model is nil' if @xml_model.nil?

          # Save the xml to the run_directory
          @xml_model.save("#{run_directory}/original.xml")
        else
          fail "Seed model #{xml_baseline} did not exist"
        end
      else
        fail 'No seed model path in JSON defined'
      end
    else
      fail 'No seed model block'
    end

    # set the initial weather file for simulation, but this may change based on the measures that are being set
    if analysis_json[:analysis]['weather_file']
      if analysis_json[:analysis]['weather_file']['path']

        # The seed path is relative to the run directory for the XML case
        @weather_fqp = File.expand_path(File.join(File.dirname(__FILE__), '..', analysis_json[:analysis]['weather_file']['path']))
        ros.log_message "Initial weather file name is #{@weather_fqp}", true
        @weather_filename = File.basename(@weather_fqp)
        @weather_path = File.dirname(@weather_fqp)

        ros.log_message "Weather file path is #{@weather_path}", true

        unless File.exist?(@weather_filename)
          ros.log_message "Could not find weather file for simulation #{@weather_filename}. Will continue because XML translation unzips files and may change the weather file"
        end
      else
        fail 'No weather file path defined'
      end
    else
      fail 'No weather file block defined'
    end

    # iterate over the workflow and grab the measures
    if analysis_json[:analysis]['problem'] && analysis_json[:analysis]['problem']['workflow'] # ugh i want indifferent access
      analysis_json[:analysis]['problem']['workflow'].each do |wf|

        if wf['measure_type'] == 'XmlMeasure'
          # need to map the variables to the XML classes
          measure_path = wf['measure_definition_directory']
          measure_name = wf['measure_definition_class_name']

          ros.log_message "XML Measure path is #{measure_path}"
          ros.log_message "XML Measure name is #{measure_name}"

          # this should only include the file if it has not already been included
          require "#{File.expand_path(File.join(File.dirname(__FILE__), '..', measure_path, 'measure'))}"

          measure = measure_name.constantize.new

          ros.log_message "iterate over arguments for workflow item #{wf['name']}", true

          # The Argument hash in the workflow json file looks like the following
          # {
          #    "display_name": "Set XPath",
          #    "machine_name": "set_xpath",
          #    "name": "xpath",
          #    "value": "/building/blocks/block/envelope/surfaces/window/layout/wwr",
          #    "uuid": "440dcce0-7663-0131-41f1-14109fdf0b37",
          #    "version_uuid": "440e4bd0-7663-0131-41f2-14109fdf0b37"
          # }
          args = {}
          if wf['arguments']
            wf['arguments'].each do |wf_arg|
              if wf_arg['value']
                ros.log_message "Setting argument value #{wf_arg['name']} to #{wf_arg['value']}", true
                # Note that these measures have symbolized hash keys and not strings.  I really want indifferential access here!
                args[wf_arg['name'].to_sym] = wf_arg['value']
                # args["#{wf_arg['name']}_machine_name".to_sym] = wf_arg['machine_name'] # i really don't want to save this...
              end
            end
          end

          ros.log_message "iterate over variables for workflow item #{wf['name']}", true
          variables_found = false
          if wf['variables']
            wf['variables'].each do |wf_var|
              # Argument hash in workflow looks like the following
              # "argument": {
              #    "display_name": "Window-To-Wall Ratio",
              #    "machine_name": "window_to_wall_ratio",
              #    "name": "value",
              #    "uuid": "a0618d15-bb0b-4494-a72f-8ad628693a7e",
              #    "version_uuid": "b33cf6b0-f1aa-4706-afab-9470e6bd1912"
              # },
              variable_uuid = wf_var['uuid'] # this is what the variable value is set to
              if wf_var['argument']
                variable_name = wf_var['argument']['name']

                # Get the value from the data point json that was set via R / Problem Formulation
                if data_point_json[:data_point]
                  if data_point_json[:data_point]['set_variable_values']
                    if data_point_json[:data_point]['set_variable_values'][variable_uuid]
                      ros.log_message "Setting variable #{variable_name} to #{data_point_json[:data_point]['set_variable_values'][variable_uuid]}"

                      # Note that these measures have symbolized hash keys and not strings.  I really want indifferential access here!
                      args[wf_var['argument']['name'].to_sym] = data_point_json[:data_point]['set_variable_values'][variable_uuid]
                      args["#{wf_var['argument']['name']}_machine_name".to_sym] = wf_var['argument']['machine_name']
                      args["#{wf_var['argument']['name']}_type".to_sym] = wf_var['value_type'] if wf_var['value_type']
                      ros.log_message "Setting the machine name for argument '#{wf_var['argument']['name']}' to '#{args["#{wf_var['argument']['name']}_machine_name".to_sym]}'"

                      # Catch a very specific case where the weather file has to be changed
                      if wf['name'] == 'location'
                        ros.log_message "VERY SPECIFIC case to change the location to #{data_point_json[:data_point]['set_variable_values'][variable_uuid]}"
                        @weather_filename = data_point_json[:data_point]['set_variable_values'][variable_uuid]
                      end
                      variables_found = true
                    else
                      ros.log_message("Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object", true)
                      fail "Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object" if CRASH_ON_NO_WORKFLOW_VARIABLE
                      break
                    end
                  else
                    fail 'No block for set_variable_values in data point record'
                  end
                else
                  fail 'No block for data_point in data_point record'
                end
              end
            end
          end

          # Run the XML Measure
          if variables_found
            xml_changed = measure.run(@xml_model, nil, args)

            # save the JSON with the changed values
            # the measure has to implement the "results_to_json" method
            measure.results_to_json("#{run_directory}/#{wf['name']}_results.json")
            # also save directly to the database
            ros.communicate_intermediate_result(measure.variable_values)
          else
            ros.log_message('No variable for measure... skipping')
          end

          ros.log_message "Finished applying measure workflow #{wf['name']} with change flag set to '#{xml_changed}'", true

        elsif wf['measure_type'] == 'EnergyPlusMeasure'
          # need to forward translate the model before applying this measure. The rest of the code will work
          # for applying the energyplus measures as they are similar to standard openstudio/ruby measures
          if @model_idf.nil?
            ros.log_message 'Translate object to EnergyPlus IDF in Prep for EnergyPlus Measure', true
            a = Time.now
            @model.getFacility
            @model.getBuilding
            forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
            # puts "starting forward translator #{Time.now}"
            @model_idf = forward_translator.translateModel(@model)
            b = Time.now
            ros.log_message "Translate object to energyplus IDF took #{b.to_f - a.to_f}", true
          end
        elsif wf['measure_type'] == 'RubyMeasure'
          # need to translate the XML to an OpenStudio object in order to run any remaining measures
          if @model.nil?
            @model = create_osm_from_xml(@xml_model, run_directory, @weather_path, @space_lib_path, ros)
          end
        end

        if wf['measure_type'] != 'XmlMeasure'
          # process the measure
          measure_path = wf['measure_definition_directory']
          measure_name = wf['measure_definition_class_name']

          require "#{File.expand_path(File.join(File.dirname(__FILE__), '..', measure_path, 'measure'))}"

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
                ros.log_message "Setting argument value #{wf_arg['name']} to #{wf_arg['value']}", true

                v = argument_map[wf_arg['name']]
                fail 'Could not find argument map in measure' unless v
                value_set = v.setValue(wf_arg['value'])
                fail "Could not set argument #{wf_arg['name']} of value #{wf_arg['value']} on model" unless value_set
                argument_map[wf_arg['name']] = v.clone
              else
                fail "Value for argument '#{wf_arg['name']}' not set in argument list" if CRASH_ON_NO_WORKFLOW_VARIABLE
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
                      ros.log_message "Setting variable #{variable_name} to #{data_point_json[:data_point]['set_variable_values'][variable_uuid]}", true
                      v = argument_map[variable_name]
                      fail 'Could not find argument map in measure' unless v
                      variable_value = data_point_json[:data_point]['set_variable_values'][variable_uuid]
                      value_set = v.setValue(variable_value)
                      fail "Could not set variable #{variable_name} of value #{variable_value} on model" unless value_set
                      argument_map[variable_name] = v.clone
                    else
                      fail "Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object" if CRASH_ON_NO_WORKFLOW_VARIABLE
                      ros.log_message("Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object", true)
                      break
                    end
                  else
                    fail 'No block for set_variable_values in data point record'
                  end
                else
                  fail 'No block for data_point in data_point record'
                end
              else
                fail "Variable '#{variable_name}' is defined but no argument is present"
              end
            end
          end

          if wf['measure_type'] == 'RubyMeasure'
            measure.run(@model, runner, argument_map)
          elsif wf['measure_type'] == 'EnergyPlusMeasure'
            measure.run(@model_idf, runner, argument_map)
          elsif wf['measure_type'] == 'ReportingMeasure'
            report_measures << measure
          end
          result = runner.result

          ros.log_message result.initialCondition.get.logMessage, true unless result.initialCondition.empty?
          ros.log_message result.finalCondition.get.logMessage, true unless result.finalCondition.empty?

          result.warnings.each { |w| ros.log_message w.logMessage, true }
          result.errors.each { |w| ros.log_message w.logMessage, true }
          result.info.each { |w| ros.log_message w.logMessage, true }
          begin
            result.attributes.each { |att| @output_attributes << JSON.parse(OpenStudio::toJSON(att)) }
          rescue Exception => e
            log_message = "TODO: #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
            ros.log_message log_message, true
          end
        end
      end
    end
  end

  # enforce the remaining part of the workflow -- this is getting out of control as expected
  if @model.nil?
    @model = create_osm_from_xml(@xml_model, run_directory, @weather_path, @space_lib_path, ros)
  end

  # ros.log_message @model.to_s
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
    ros.log_message 'Translate object to energyplus IDF', true
    a = Time.now
    @model.getFacility
    @model.getBuilding
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    # puts "starting forward translator #{Time.now}"
    @model_idf = forward_translator.translateModel(@model)
    b = Time.now
    ros.log_message "Translate object to energyplus IDF took #{b.to_f - a.to_f}", true
  end

  # Run EnergyPlus using run energyplus script
  idf_filename = "#{run_directory}/in.idf"
  File.open(idf_filename, 'w') { |f| f << @model_idf.to_s }

  ros.log_message 'Verifying location of Post Process Script', true
  post_process_filename = File.expand_path(File.join(File.dirname(__FILE__), 'post_process.rb'))
  if File.exist?(post_process_filename)
    ros.log_message "Post process file is #{post_process_filename}"
  else
    fail "Could not find post process file #{post_process_filename}"
  end

  ros.log_message 'Waiting for simulation to finish', true
  command = "ruby #{run_directory}/run_energyplus.rb -a #{run_directory} -i #{idf_filename} -o #{osm_filename} "\
            "-w #{@weather_path}/#{@weather_filename} -p #{post_process_filename}"
  # command += " -e #{run_args[:energyplus]}" unless run_args.nil?
  # command += " --idd-path #{run_args[:idd]}" unless run_args.nil?
  # command += " --support-files #{support_files}" unless support_files.nil?
  ros.log_message command, true
  result = `#{command}`

  ros.log_message 'Simulation finished', true
  ros.log_message "Simulation results #{result}", true

  # use the completed job to populate data_point with results
  ros.log_message 'Updating OpenStudio DataPoint and Communicating Results', true

  # HARD CODE the running of the report measure --- eventually loop of the workflow and
  # run any post processing
  ros.log_message 'Running OpenStudio Post Processing'
  measure_path = 'packaged_measures'
  measure_name = 'StandardReports'

  # when full workflow then do this
  # require "#{File.expand_path(File.join(File.dirname(__FILE__), '..', measure_path, measure_name, 'measure'))}"
  require "#{File.expand_path(File.join(File.dirname(__FILE__), measure_path, measure_name, 'measure'))}"

  measure = measure_name.constantize.new
  runner = OpenStudio::Ruleset::OSRunner.new
  arguments = measure.arguments

  ros.log_message "Run directory for post process: #{run_directory}"
  runner.setLastOpenStudioModel(@model)
  runner.setLastEnergyPlusSqlFilePath("#{run_directory}/run/eplusout.sql")

  # set argument values to good values and run the measure
  argument_map = OpenStudio::Ruleset::OSArgumentMap.new
  measure.run(runner, argument_map)
  result = runner.result

  ros.log_message 'Finished OpenStudio Post Processing'
  ros.log_message result.initialCondition.get.logMessage, true unless result.initialCondition.empty?
  ros.log_message result.finalCondition.get.logMessage, true unless result.finalCondition.empty?

  result.warnings.each { |w| ros.log_message w.logMessage, true }
  result.errors.each { |w| ros.log_message w.logMessage, true }
  result.info.each { |w| ros.log_message w.logMessage, true }

  report_json = JSON.parse(OpenStudio.toJSON(result.attributes), symbolize_names: true)
  ros.log_message "JSON file is #{report_json}"
  File.open("#{run_directory}/standard_report.json", 'w') { |f| f << JSON.pretty_generate(report_json) }

  # report the attributes of each of the measures
  ros.log_message "Measure output attributes are #{@output_attributes}"
  File.open("#{run_directory}/measure_attributes.json", 'w') { |f| f << JSON.pretty_generate(@output_attributes) }

  # If profiling, then go ahead and get the results here.  Note that we are not profiling the
  # result of saving the json data and pushing the data back to mongo because the "communicate_results_json" method
  # also ZIPs up the folder and we want the results of the performance to also be in ZIP file.
  if options[:profile_run]
    profile_results = RubyProf.stop
    File.open("#{directory}/profile-graph.html", 'w') { |f| RubyProf::GraphHtmlPrinter.new(profile_results).print(f) }
    File.open("#{directory}/profile-flat.txt", 'w') { |f| RubyProf::FlatPrinter.new(profile_results).print(f) }
    File.open("#{directory}/profile-tree.prof", 'w') { |f| RubyProf::CallTreePrinter.new(profile_results).print(f) }
  end

  # Initialize the objective function variable
  objective_functions = {}
  if File.exist?("#{run_directory}/run/eplustbl.json")
    result_json = JSON.parse(File.read("#{run_directory}/run/eplustbl.json"), symbolize_names: true)
    ros.log_message "Result JSON is: #{result_json}"
    ros.log_message "Analysis JSON Output Variables are: #{analysis_json[:analysis]['output_variables']}"
    # Save the objective functions to the object for sending back to the simulation executive
    analysis_json[:analysis]['output_variables'].each do |variable|
      # determine which ones are the objective functions (code smell: todo: use enumerator)
      if variable['objective_function']
        ros.log_message "Found objective function for #{variable['name']}", true
        if result_json[variable['name'].to_sym]
          # objective_functions[variable['name']] = result_json[variable['name'].to_sym]
          objective_functions["objective_function_#{variable['objective_function_index'] + 1}"] = result_json[variable['name'].to_sym]
          if variable['objective_function_target']
            ros.log_message "Found objective function target for #{variable['name']}", true
            objective_functions["objective_function_target_#{variable['objective_function_index'] + 1}"] = variable['objective_function_target'].to_f
          end
          if variable['scaling_factor']
            ros.log_message "Found scaling factor for #{variable['name']}", true
            objective_functions["scaling_factor_#{variable['objective_function_index'] + 1}"] = variable['scaling_factor'].to_f
          end
          if variable['objective_function_group']
            ros.log_message "Found objective function group for #{variable['name']}", true
            objective_functions["objective_function_group_#{variable['objective_function_index'] + 1}"] = variable['objective_function_group'].to_f
          end
        else
          # objective_functions[variable['name']] = nil
          objective_functions["objective_function_#{variable['objective_function_index'] + 1}"] = Float::MAX
          objective_functions["objective_function_target_#{variable['objective_function_index'] + 1}"] = nil
          objective_functions["scaling_factor_#{variable['objective_function_index'] + 1}"] = nil
          objective_functions["objective_function_group_#{variable['objective_function_index'] + 1}"] = nil
        end
      end
    end

    # todo: make sure that the result_json file is a superset of the other variables in the variable list
    ros.log_message 'Communicating data back to server'
    # map the result json back to a flat array
    ros.log_message "Result JSON #{result_json}"
    ros.communicate_results_json(result_json, run_directory)
    ros.log_message 'After communicate_results_json()'
  end

  # save the objective function results
  obj_fun_file = "#{run_directory}/objectives.json"
  ros.log_message "Saving objective function file #{obj_fun_file}"
  ros.log_message "Objective Function JSON is #{objective_functions}"
  File.rm_f(obj_fun_file) if File.exist?(obj_fun_file)
  File.open(obj_fun_file, 'w') { |f| f << JSON.pretty_generate(objective_functions) }

  # map the objective function results to an array
  obj_function_array = objective_functions.map { |k, v| v }
rescue Exception => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  ros.log_message log_message, true

  # need to tell the system that this failed
  ros.communicate_failure run_directory
ensure
  ros.log_message "#{__FILE__} Completed", true

  obj_function_array ||= ['NA']

  # Print the objective functions to the screen even though the file is being used right now
  # Note as well that we can't guarantee that the csv format will be in the right order
  puts obj_function_array.join(',')
end
