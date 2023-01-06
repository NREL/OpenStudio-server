# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
require "openstudio-extension"
class TestScripts < OpenStudio::Measure::ModelMeasure
  require "openstudio-standards"
  def name
    # Measure name should be the title case of the class name.
    return 'test scripts'
  end

  # human readable description
  def description
    return 'test scripts'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'test scripts'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # the name of the space to add to the model
    space_name = OpenStudio::Measure::OSArgument.makeStringArgument('space_name', true)
    space_name.setDisplayName('New space name')
    space_name.setDescription('This name will be used as the name of the new space.')
    args << space_name

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
    space_name = runner.getStringArgumentValue('space_name', user_arguments)

    # report initial condition of model
    runner.registerInfo("OpenstudioStandards::VERSION = #{OpenstudioStandards::VERSION}")

    return true
  end
end

# register the measure to be used by the application
TestScripts.new.registerWithApplication
