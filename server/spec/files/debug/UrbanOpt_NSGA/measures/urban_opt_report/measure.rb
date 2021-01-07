# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'json'

# start the measure
class UrbanOptReport < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'UrbanOptReport'
  end

  # human readable description
  def description
    return 'UrbanOptReport'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'UrbanOptReport'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    scenario_name = OpenStudio::Measure::OSArgument.makeStringArgument('scenario_name', false)
    scenario_name.setDisplayName('scenario_name')
    scenario_name.setDefaultValue('highefficiency_scenario')
    args << scenario_name
    
    id = OpenStudio::Measure::OSArgument.makeIntegerArgument('feature_id', false)
    id.setDisplayName('Feature unique identifier')
    id.setDefaultValue('1')
    args << id
    
    output_name_chs = OpenStudio::StringVector.new    
    output_name_chs << 'total_site_energy'
    output_name_chs << 'total_source_energy'
    output_name_chs << 'net_site_energy'
    output_name_chs << 'net_source_energy'
    output_name_chs << 'electricity'
    output_name_chs << 'natural_gas'
    output_name_chs << 'additional_fuel'
    output_name_chs << 'district_cooling'
    output_name_chs << 'district_heating'
    output_name_chs << 'water'
    output_name_chs << 'electricity_produced'
      
    output_name = OpenStudio::Measure::OSArgument.makeChoiceArgument('output_name', output_name_chs, true)
    output_name.setDisplayName('output_name')
    output_name.setDefaultValue('total_site_energy')
    args << output_name

    
    return args
  end

  # define the outputs that the measure will create
  def outputs
    result = OpenStudio::Measure::OSOutputVector.new

    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('output')

    return result
  end


  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    id = runner.getIntegerArgumentValue('feature_id', user_arguments)
    output_name = runner.getStringArgumentValue('output_name', user_arguments)
    scenario_name = runner.getStringArgumentValue('scenario_name', user_arguments)

    pre_path = "../../urbanopt/run/#{scenario_name}/#{id}"
    if !File.directory?(pre_path)
      runner.registerError("directory path: #{pre_path} does not exist")
      return false
    end
    
    path = Dir["#{pre_path}/*default_feature_reports"]
    if !File.directory?(path[0])
      runner.registerError("directory path: #{path[0]} does not exist")
      return false
    end
    
    full_path = path[0] + "/default_feature_reports.json"
    if !File.exist?(full_path)
      runner.registerError("file path: #{full_path} does not exist")
      return false
    else
      runner.registerInfo("UrbanOpt Report full_path: #{full_path}")
    end
    
    json = {}
    output = nil
    json = JSON.parse(File.read(full_path), symbolize_names: true) if File.exist? full_path
    if json.empty?
      runner.registerError("the default_feature_reports.json is empty at #{full_path}")
      return false
    end
    
    output = json[:reporting_periods][0][:"#{output_name}"]
    if output.nil?
      runner.registerError("output_name: #{output_name} is not in default_feature_reports.json at json[:reporting_periods][0][:outputname]")
      return false
    end
    
    runner.registerInfo("UrbanOpt Report output: #{output}")
    runner.registerValue("#{output_name}", output, '')

    return true
  end
end

# register the measure to be used by the application
UrbanOptReport.new.registerWithApplication
