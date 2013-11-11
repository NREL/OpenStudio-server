#see the URL below for information on how to write OpenStuido measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on mondel objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class AddOutputVariable < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "AddOutputVariable"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make an argument for the varialbe name
    variable_name = OpenStudio::Ruleset::OSArgument::makeStringArgument("variable_name",true)
    variable_name.setDisplayName("Enter Variable Name.")
    args << variable_name
    
    #make an argument for the electric tariff
    reporting_frequency_chs = OpenStudio::StringVector.new
    reporting_frequency_chs << "detailed"
    reporting_frequency_chs << "timestep"
    reporting_frequency_chs << "hourly"
    reporting_frequency_chs << "daily"
    reporting_frequency_chs << "monthly"
    reporting_frequency = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('reporting_frequency', reporting_frequency_chs, true)
    reporting_frequency.setDisplayName("Reporting Frequency.")
    reporting_frequency.setDefaultValue("hourly")
    args << reporting_frequency    

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    variable_name = runner.getStringArgumentValue("variable_name",user_arguments)
    reporting_frequency = runner.getStringArgumentValue("reporting_frequency",user_arguments) 
    
    #check the user_name for reasonableness
    if variable_name == ""
      runner.registerError("No variable name was entered.")
      return false
    end
    
    outputVariables = model.getOutputVariables    
    #reporting initial condition of model
    starting_spaces = model.getSpaces
    runner.registerInitialCondition("The model started with #{outputVariables.size} output variable objects.")

    outputVariable = OpenStudio::Model::OutputVariable.new(variable_name,model)
    outputVariable.setReportingFrequency(reporting_frequency)
    runner.registerInfo("Adding output variable for #{outputVariable.variableName} reporting #{reporting_frequency}")

    outputVariables = model.getOutputVariables    
    #reporting final condition of model
    finishing_spaces = model.getSpaces
    runner.registerFinalCondition("The model finished with #{outputVariables.size} output variable objects.")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
AddOutputVariable.new.registerWithApplication