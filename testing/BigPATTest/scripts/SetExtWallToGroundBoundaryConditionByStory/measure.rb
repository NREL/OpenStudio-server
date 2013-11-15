#see the URL below for information on how to write OpenStuido measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on mondel objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class SetExtWallToGroundBoundaryConditionByStory < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "SetExtWallToGroundBoundaryConditionByStory"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #populate choice argument for storys that are applied to surfaces in the model
    storyBasement_handles = OpenStudio::StringVector.new
    storyBasement_display_names = OpenStudio::StringVector.new

    #putting stories and names into hash
    storyBasement_args = model.getBuildingStorys
    storyBasement_args_hash = {}
    storyBasement_args.each do |storyBasement_arg|
      storyBasement_args_hash[storyBasement_arg.name.to_s] = storyBasement_arg
    end

    #looping through sorted hash of storys
    storyBasement_args_hash.sort.map do |key,value|
      storyBasement_handles << value.handle.to_s
      storyBasement_display_names << key
    end

    #make an argument for storyBasement
    #todo - warn user if surface has any sub-surfaces.
    storyBasement = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("storyBasement", storyBasement_handles, storyBasement_display_names,true)
    storyBasement.setDisplayName("Choose a Story to Change Wall Boundary Conditions For.")
    args << storyBasement
    
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
    storyBasement = runner.getOptionalWorkspaceObjectChoiceValue("storyBasement",user_arguments,model) #model is passed in because of argument type

    #check the storyBasement for reasonableness
    if storyBasement.empty?
      handle = runner.getStringArgumentValue("storyBasement",user_arguments)
      if handle.empty?
        runner.registerError("No storyBasement was chosen.")
      else
        runner.registerError("The selected storyBasement with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not storyBasement.get.to_BuildingStory.empty?
        storyBasement = storyBasement.get.to_BuildingStory.get
      else
        runner.registerError("Script Error - argument not showing up as storyBasement.")
        return false
      end
    end #end of storyBasement.empty?

    stories = model.getBuildingStorys

    #reporting initial condition of model
    runner.registerInitialCondition("The building has #{stories.size} stories.")

    affectedSpaces = storyBasement.spaces
    affectedSpaces.each do |story|
      surfaces = story.surfaces
      surfaces.each do |surface|
        if surface.surfaceType == "Wall" and surface.outsideBoundaryCondition == "Outdoors"
          surface.setOutsideBoundaryCondition("Ground")
        end
      end 
    end #end of affectedSpaces.each do

    #reporting final condition of model
    runner.registerFinalCondition("Exterior walls on #{storyBasement.name} now have a ground boundary condition.")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
SetExtWallToGroundBoundaryConditionByStory.new.registerWithApplication