
def test_run_user_script(user_script_path,input_file_path,output_file_path,user_args)

  # GET THE USER SCRIPT
  require user_script_path
  user_script_path = OpenStudio::Path.new(user_script_path)
  user_script = nil
  type = String.new
  ObjectSpace.each_object(OpenStudio::Ruleset::UserScript) do |obj|
    if obj.is_a? OpenStudio::Ruleset::ModelUserScript
      user_script = obj
      type = "model"
      break
    elsif obj.is_a? OpenStudio::Ruleset::WorkspaceUserScript
      user_script = obj
      type = "workspace"
      break
    elsif obj.is_a? OpenStudio::Rulset::TranslationUserScript
      user_script = obj
      type = "translation"
      break
    end
  end
  #stop if not user script found or not loadable
  if not user_script
    raise "Unable to locate user_script class in " + user_script_path.to_s + 
          ", you may need to instantiate the newly defined OpenStudio::Rulset::user_script class at "
          "the end of the file to enable finding by introspection."
  else
    puts "Found user_script '" + user_script.name + "'."
  end

  # LOAD THE INPUT MODEL
  input_file_path = OpenStudio::Path.new(input_file_path)
  model = OpenStudio::Model::Model.new
  workspace = OpenStudio::Workspace.new("Draft".to_StrictnessLevel,"EnergyPlus".to_IddFileType)
  input_data = nil
  save_model = true
  if type == "model"
    if OpenStudio::exists(input_file_path)
      versionTranslator = OpenStudio::OSVersion::VersionTranslator.new 
      model = versionTranslator.loadModel(input_file_path)
      if model.empty?
        puts "Version translation failed for #{model_path_string}"
        exit
      else
        model = model.get
      end
    else
      puts "#{model_path_string} couldn't be found"
      exit
    end    
    input_data = model
  elsif type == "workspace"
    workspace = OpenStudio::Workspace::load(input_file_path,"EnergyPlus".to_IddFileType)
    raise "Unable to load OpenStudio Workspace from  *#{input_file_path}*" if workspace.empty?
    workspace = workspace.get
    save_model = false
    input_data = workspace
  else
    raise "type of script not recognized"
  end

  #make sure that the arguments specified by the user are the same
  #as the arguments that the measure wants
  argument_map = OpenStudio::Ruleset::OSArgumentMap.new
  arguments = user_script.arguments(input_data)
  arguments.each do |argument|
    argument_with_name_exists = false
    #puts "the measure is looking for an argument called #{argument.name}"
    user_args.each do |user_arg_name, user_arg_value|
      #puts " - the user input an argument with name = #{user_arg_name} and value = #{user_arg_value}"
      if user_arg_name == argument.name
        argument.setValue(user_arg_value)
        argument_map[user_arg_name] = argument
        #puts "the argument has a value assigned = #{argument.hasValue}"
        argument_with_name_exists = true
        break
      end
    end
    #warn the user if they forgot to input an argument and
    #that argument wasn't found and also has no default
    #if argument_with_name_exists == false
      #if argument.required and not argument.hasDefaultValue
        #raise "User must specify value for argument '" + argument.name + "'."
      #end
    #end
  end
  
  # RUN SCRIPT WITH DEFAULT RUNNER AND SAVE OUTPUT
  runner = OpenStudio::Ruleset::OSRunner.new
  if type == "model"
    result = user_script.run(model,runner,argument_map)
  elsif type == "workspace"
    result = user_script.run(workspace,runner,argument_map)
  end

  #output the messages to the ruby console (User will not see this, for testing only)
  runner_results = runner.result

  puts "**MEASURE APPLICABILITY**"
  applicability = runner_results.value.value
  if applicability ==  -1
    puts "#{applicability} = Not Applicable"
  elsif applicability == 0 
    puts "#{applicability} = Success"
  elsif applicability == 1 
    puts "#{applicability} = Fail"
  end
 
  puts "**INITIAL CONDITION**"
  if runner_results.initialCondition.empty?
    #do nothing
  else
    puts runner_results.initialCondition.get.logMessage
  end  
      
  puts "**FINAL CONDITION**"
  if runner_results.finalCondition.empty?
    #do nothing
  else
    puts runner_results.finalCondition.get.logMessage
  end    
  
  puts "**INFO MESSAGES**"  
  runner_results.info.each do |info_msg|
    puts "#{info_msg.logMessage}"
  end

  puts "**WARNING MESSAGES**"  
  runner_results.warnings.each do |info_msg|
    puts "#{info_msg.logMessage}"
  end

  puts "**ERROR MESSAGES**"  
  runner_results.errors.each do |info_msg|
    puts "#{info_msg.logMessage}"
  end

  puts "" #space between measures for readability in output
  puts ""

  # SAVE OUTPUT MODEL
  output_file_path = OpenStudio::Path.new(output_file_path)
  if type == "model"
    model.save(output_file_path,true)
  elsif type == "workspace"
   workspace.save(output_file_path,true)
  end
  
end  
