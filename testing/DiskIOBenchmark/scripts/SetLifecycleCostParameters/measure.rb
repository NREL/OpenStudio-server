#see the URL below for information on how to write OpenStuido measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on mondel objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class SetLifecycleCostParameters < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "SetLifecycleCostParameters"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make an argument for your name
    study_period = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("study_period",true)
    study_period.setDisplayName("Set the Length of the Study Period (years).")
    study_period.setDefaultValue(25)
    args << study_period
    
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
    study_period = runner.getIntegerArgumentValue("study_period",user_arguments)
    
    #check the user_name for reasonableness
    if study_period < 1
      runner.registerError("Length of the Study Period needs to be an integer greater than 0.")
      return false
    end 
    
    #get lifecycle object
    lifeCycleCostParameters = model.getLifeCycleCostParameters

    #reporting initial condition of model
    starting_spaces = model.getSpaces
    runner.registerInitialCondition("Initial Lifecycle Analysis Type is #{lifeCycleCostParameters.analysisType}. Initial Analysis Length is #{lifeCycleCostParameters.lengthOfStudyPeriodInYears}.")

    #this will eventually be in the GUI, but just adding to measure for now
    lifeCycleCostParameters.setAnalysisType("FEMP")
    lifeCycleCostParameters.setLengthOfStudyPeriodInYears(study_period)

    #reporting final condition of model
    finishing_spaces = model.getSpaces
    runner.registerFinalCondition("Final Lifecycle Analysis Type is #{lifeCycleCostParameters.analysisType}. Final Analysis Length is #{lifeCycleCostParameters.lengthOfStudyPeriodInYears}.")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
SetLifecycleCostParameters.new.registerWithApplication