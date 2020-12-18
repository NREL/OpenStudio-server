# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class UrbanOptReopt < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'UrbanOptReopt'
  end

  # human readable description
  def description
    return 'Change UrbanOpt Reopt [:Scenario][:Site][:category_key][:sub_category_key => value]'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Change UrbanOpt Reopt [:Scenario][:Site][:category_key][:sub_category_key => value]'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # the name of the space to add to the model
    scenario_file_name = OpenStudio::Measure::OSArgument.makeStringArgument('scenario_file_name', true)
    scenario_file_name.setDisplayName('scenario File name')
    scenario_file_name.setDescription('This is the name of the scenario file to apply changes to. (no .json) ex: base_assumptions')
    scenario_file_name.setDefaultValue('base_assumptions')
    args << scenario_file_name
   
    # category_key
    category_key = OpenStudio::Measure::OSArgument.makeStringArgument('category_key', true)
    category_key.setDisplayName('category_key')
    category_key.setDescription('json category_key (no colon), ex: Financial')
    category_key.setDefaultValue('Financial')
    args << category_key
    
    # sub_category_key
    sub_category_key = OpenStudio::Measure::OSArgument.makeStringArgument('sub_category_key', true)
    sub_category_key.setDisplayName('sub_category_key')
    sub_category_key.setDescription('json sub_category_key (no colon), ex: analysis_years')
    sub_category_key.setDefaultValue('analysis_years')
    args << sub_category_key
    
    # value
    value = OpenStudio::Measure::OSArgument.makeDoubleArgument('value', true)
    value.setDisplayName('value')
    value.setDescription('value')
    value.setDefaultValue(0)
    args << value
    
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    scenario_file_name = runner.getStringArgumentValue('scenario_file_name', user_arguments)
    value = runner.getDoubleArgumentValue('value', user_arguments)
    category_key = runner.getStringArgumentValue('category_key', user_arguments)
    sub_category_key = runner.getStringArgumentValue('sub_category_key', user_arguments)
    found = false
    
    #TODO try and get simulation_dir value
    #scenario_file_path = "#{simulation_dir}/urbanopt/#{scenario_file_name}.json"
    scenario_file_path = "../../urbanopt/reopt/#{scenario_file_name}.json"
    if File.exist?(scenario_file_path)
      scenario_file = JSON.parse(File.read(scenario_file_path), symbolize_names: true)
    else
      runner.registerError("reopt scenario File: #{scenario_file_path} could not be found!")
      return false
    end
    #loop over scenarios
    
    scenario_file[:Scenario][:Site].each do |category|
      #find category
      if category[0].to_sym == category_key.to_sym
        runner.registerInfo("category_key found: #{category_key}")
        scenario_file[:Scenario][:Site][category_key.to_sym].each do |sub_category|
          runner.registerInfo("sub_category: #{sub_category}")
          if sub_category[0] == sub_category_key.to_sym
            runner.registerInfo("sub_category_key found: #{sub_category_key}, change value to: #{value}")
            scenario_file[:Scenario][:Site][category_key.to_sym][sub_category_key.to_sym] = value
            runner.registerInfo("scenario_file[:Scenario][:Site][category_key.to_sym][sub_category_key.to_sym]: #{scenario_file[:Scenario][:Site][category_key.to_sym][sub_category_key.to_sym]}")
            found = true
          end
        end
      end
    end
    
    if found == false
      runner.registerWarning("saved #{[:Scenario][:Site][category.to_sym][sub_category.to_sym]} was not found in file: #{scenario_file_name}.json!")    
    end
    #write_size = File.write(scenario_file_path, scenario_file.to_json)
    write_size = File.write(scenario_file_path, JSON.pretty_generate(scenario_file))
    if write_size >= 0
      runner.registerFinalCondition("saved #{scenario_file_name}")
    else
      runner.registerWarning("saved #{scenario_file_name} was size zero!")
    end    
    return true
  end
end

# register the measure to be used by the application
UrbanOptReopt.new.registerWithApplication
