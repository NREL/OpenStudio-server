#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class SetInteriorWallsAndFloorsToAdiabatic < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "SetInteriorWallsAndFloorsToAdiabatic"
  end

  #todo - need to bools for wall and floor, and two constructions choices, and then update code to loop through floors as well as walls.
  #todo - short warn abot or skip if there are sub-surfaces (unless I offer boll to remove them)

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for storys that are applied to surfaces in the model
    construction_handles = OpenStudio::StringVector.new
    construction_display_names = OpenStudio::StringVector.new

    #putting stories and names into hash
    construction_args = model.getConstructions
    construction_args_hash = {}
    construction_args.each do |construction_arg|
      construction_args_hash[construction_arg.name.to_s] = construction_arg
    end

    #looping through sorted hash of storys
    construction_args_hash.sort.map do |key,value| #todo - could filter this so only constructions that are valid on opaque surfaces will show up.
      construction_handles << value.handle.to_s
      construction_display_names << key
    end

    #make an argument for construction
    construction = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("construction", construction_handles, construction_display_names,true)
    construction.setDisplayName("Select New Construction.")
    args << construction

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
    construction= runner.getOptionalWorkspaceObjectChoiceValue("construction",user_arguments,model) #model is passed in because of argument type

    #check the construction for reasonableness
    if construction.empty?
      handle = runner.getStringArgumentValue("construction",user_arguments)
      if handle.empty?
        runner.registerError("No construction was chosen.")
      else
        runner.registerError("The selected construction with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not construction.get.to_Construction.empty?
        construction = construction.get.to_Construction.get
      else
        runner.registerError("Script Error - argument not showing up as construction.")
        return false
      end
    end #end of storyBasement.empty?

    #counter for number of constructions use for interior walls in initial construction
    interior_walls = 0

    #make an array of walls that started as matched surfaces.
    #I need to do this first, because when one of pair changes to Adiabatic, the other will change to Outdoors
    surfaces_to_change = []
    surfaces = model.getSurfaces
    surfaces.each do |surface|
      if surface.surfaceType == "Wall" and surface.outsideBoundaryCondition == "Surface"
        surfaces_to_change << surface
      end
    end

    #change boundary condition and assign constructions
    surfaces_to_change.each do |surface|
      surface.setConstruction(construction)
      surface.setOutsideBoundaryCondition("Adiabatic")
      interior_walls += 1
    end

    #reporting initial condition of model
    runner.registerInitialCondition("The initial model has #{interior_walls/2} pairs of interior wall surfaces.")

    #reporting final condition of model
    finishing_spaces = model.getSpaces
    runner.registerFinalCondition("All interior walls surfaces now use #{construction.name} for the construction.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
SetInteriorWallsAndFloorsToAdiabatic.new.registerWithApplication