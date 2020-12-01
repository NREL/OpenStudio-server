# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class UrbanOptSpaces < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'UrbanOptSpaces'
  end

  # human readable description
  def description
    return 'Change UrbanOpt Space percentages'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Change UrbanOpt Space percentages'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # the name of the space to add to the model
    feature_file_name = OpenStudio::Measure::OSArgument.makeStringArgument('feature_file_name', true)
    feature_file_name.setDisplayName('Feature File name')
    feature_file_name.setDescription('This is the name of the Feature file to apply changes to. (no .json)')
    args << feature_file_name
    
    # the name of the space to add to the model
    feature_id = OpenStudio::Measure::OSArgument.makeStringArgument('feature_id', true)
    feature_id.setDisplayName('Feature ID')
    feature_id.setDescription('This is the string for the Feature ID to apply changes to.')
    args << feature_id
    
    # mixed_type_1_percentage
    mixed_type_1_percentage = OpenStudio::Measure::OSArgument.makeDoubleArgument('mixed_type_1_percentage', true)
    mixed_type_1_percentage.setDisplayName('mixed_type_1_percentage')
    mixed_type_1_percentage.setDescription('mixed_type_1_percentage')
    mixed_type_1_percentage.setDefaultValue(0)
    args << mixed_type_1_percentage

    # mixed_type_2_percentage
    mixed_type_2_percentage = OpenStudio::Measure::OSArgument.makeDoubleArgument('mixed_type_2_percentage', true)
    mixed_type_2_percentage.setDisplayName('mixed_type_2_percentage')
    mixed_type_2_percentage.setDescription('mixed_type_2_percentage')
    mixed_type_2_percentage.setDefaultValue(0)
    args << mixed_type_2_percentage
    
    # mixed_type_3_percentage
    mixed_type_3_percentage = OpenStudio::Measure::OSArgument.makeDoubleArgument('mixed_type_3_percentage', true)
    mixed_type_3_percentage.setDisplayName('mixed_type_3_percentage')
    mixed_type_3_percentage.setDescription('mixed_type_3_percentage')
    mixed_type_3_percentage.setDefaultValue(0)
    args << mixed_type_3_percentage
    
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
    feature_file_name = runner.getStringArgumentValue('feature_file_name', user_arguments)
    feature_id = runner.getStringArgumentValue('feature_id', user_arguments)
    mixed_type_1_percentage = runner.getDoubleArgumentValue('mixed_type_1_percentage', user_arguments)
    mixed_type_2_percentage = runner.getDoubleArgumentValue('mixed_type_2_percentage', user_arguments)
    mixed_type_3_percentage = runner.getDoubleArgumentValue('mixed_type_3_percentage', user_arguments)
    
    #TODO try and get simulation_dir value
    #feature_file_path = "#{simulation_dir}/urbanopt/#{feature_file_name}.json"
    feature_file_path = "../../urbanopt/#{feature_file_name}.json"
    if File.exist?(feature_file_path)
      feature_file = JSON.parse(File.read(feature_file_path), symbolize_names: true)
    else
      runner.registerError("Feature File: #{feature_file_path} could not be found!")
      return false
    end
    #loop over features
    feature_file[:features].each do |feature|
      #find feature_id
      if feature[:properties][:id] == feature_id
        runner.registerInfo("feature_id: #{feature[:properties][:id]}")
        #Handle constraint
        mixed_type_4_percentage = 100.0 - mixed_type_3_percentage - mixed_type_2_percentage - mixed_type_1_percentage
        if mixed_type_4_percentage < 0.0
          runner.registerWarning("mixed_type_4_percentage = #{mixed_type_4_percentage} is < 0!")
          mixed_type_4_percentage = 0
        end
        feature[:properties][:mixed_type_1_percentage] = mixed_type_1_percentage
        feature[:properties][:mixed_type_2_percentage] = mixed_type_2_percentage
        feature[:properties][:mixed_type_3_percentage] = mixed_type_3_percentage
        feature[:properties][:mixed_type_4_percentage] = mixed_type_4_percentage
        
        runner.registerInfo("mixed_type_1_percentage: #{feature[:properties][:mixed_type_1_percentage]}")
        runner.registerInfo("mixed_type_2_percentage: #{feature[:properties][:mixed_type_2_percentage]}")
        runner.registerInfo("mixed_type_3_percentage: #{feature[:properties][:mixed_type_3_percentage]}")
        runner.registerInfo("mixed_type_4_percentage: #{feature[:properties][:mixed_type_4_percentage]}")        
      end
    end

    #write_size = File.write(feature_file_path, feature_file.to_json)
    write_size = File.write(feature_file_path, JSON.pretty_generate(feature_file))
    if write_size >= 0
      runner.registerFinalCondition("saved #{feature_file_name}")
    else
      runner.registerWarning("saved #{feature_file_name} was size zero!")
    end    
    return true
  end
end

# register the measure to be used by the application
UrbanOptSpaces.new.registerWithApplication
