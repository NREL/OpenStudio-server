#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class SwapLightsDefinition < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "SwapLightsDefinition"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for lights_defs that are applied to surfaces in the model
    old_lights_def_handles = OpenStudio::StringVector.new
    old_lights_def_display_names = OpenStudio::StringVector.new

    #putting space types and names into hash
    old_lights_def_args = model.getLightsDefinitions
    old_lights_def_args_hash = {}
    old_lights_def_args.each do |old_lights_def_arg|
      old_lights_def_args_hash[old_lights_def_arg.name.to_s] = old_lights_def_arg
    end

    #looping through sorted hash of old_lights_defs
    old_lights_def_args_hash.sort.map do |key,value|
      #only include if old_lights_def is an old_lights_def, if it is used in a space
      if value.quantity > 0
        old_lights_def_handles << value.handle.to_s
        old_lights_def_display_names << key
      end
    end

    #make an argument for old_lights_def
    old_lights_def = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("old_lights_def", old_lights_def_handles, old_lights_def_display_names,true)
    old_lights_def.setDisplayName("Choose the Lights Definition you Want to Replace.")
    args << old_lights_def

    #populate choice argument for new_lights_defs that are applied to surfaces in the model
    new_lights_def_handles = OpenStudio::StringVector.new
    new_lights_def_display_names = OpenStudio::StringVector.new

    #putting space types and names into hash
    new_lights_def_args = model.getLightsDefinitions
    new_lights_def_args_hash = {}
    new_lights_def_args.each do |new_lights_def_arg|
      new_lights_def_args_hash[new_lights_def_arg.name.to_s] = new_lights_def_arg
    end

    #looping through sorted hash of new_lights_defs
    new_lights_def_args_hash.sort.map do |key,value|
      #include ANY new_lights_def
      new_lights_def_handles << value.handle.to_s
      new_lights_def_display_names << key
    end

    #make an argument for new_lights_def
    new_lights_def = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("new_lights_def", new_lights_def_handles, new_lights_def_display_names,true)
    new_lights_def.setDisplayName("Choose the Lights Definition to Use in Place of Removed Definition.")
    args << new_lights_def

    #make an argument to determine if demolition costs should be included in initial Definition
    demo_cost_initial_const = OpenStudio::Ruleset::OSArgument::makeBoolArgument("demo_cost_initial_const",true)
    demo_cost_initial_const.setDisplayName("Demolition Costs Occur During Initial Definition?")
    demo_cost_initial_const.setDefaultValue(false)
    args << demo_cost_initial_const

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
    old_lights_def = runner.getOptionalWorkspaceObjectChoiceValue("old_lights_def",user_arguments,model) #model is passed in because of argument type
    new_lights_def = runner.getOptionalWorkspaceObjectChoiceValue("new_lights_def",user_arguments,model) #model is passed in because of argument type
    demo_cost_initial_const = runner.getBoolArgumentValue("demo_cost_initial_const",user_arguments)

    #check the Definition for reasonableness
    if old_lights_def.empty?
      handle = runner.getStringArgumentValue("old_lights_def",user_arguments)
      if handle.empty?
        runner.registerError("No Lights Definition was chosen.")
      else
        runner.registerError("The selected Lights Definition with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not old_lights_def.get.to_LightsDefinition.empty?
        old_lights_def = old_lights_def.get.to_LightsDefinition.get
      else
        runner.registerError("Script Error - argument not showing up as Lights Definition.")
        return false
      end
    end  #end of if old_lights_def.empty?

    if new_lights_def.empty?
      handle = runner.getStringArgumentValue("new_lights_def",user_arguments)
      if handle.empty?
        runner.registerError("No Lights Definition was chosen.")
      else
        runner.registerError("The selected Lights Definition with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not new_lights_def.get.to_LightsDefinition.empty?
        new_lights_def = new_lights_def.get.to_LightsDefinition.get
      else
        runner.registerError("Script Error - argument not showing up as Lights Definition.")
        return false
      end
    end  #end of if new_lights_def.empty?

    #warn user if selected definitions have different load methods (e.g. lpd and lighting power)
    if not old_lights_def.designLevelCalculationMethod == new_lights_def.designLevelCalculationMethod
      runner.registerWarning("#{old_lights_def.name} and #{new_lights_def.name} have different design level calculation methods.")
    end

    #helper to make numbers pretty (converts 4125001.25641 to 4,125,001.26 or 4,125,001). The definition be called through this measure.
    def neat_numbers(number, roundto = 2) #round to 0 or 2)
      if roundto == 2
        number = sprintf "%.2f", number
      else
        number = number.round
      end
      #regex to add commas
      number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
    end #end def neat_numbers

    def add_to_baseline_demo_cost_counter(baseline_object, demo_cost_initial_const)
      counter = 0
      if demo_cost_initial_const == true
        baseline_object_LCCs = baseline_object.lifeCycleCosts
        baseline_object_LCCs.each do |baseline_object_LCC|
          if baseline_object_LCC.category == "Salvage"
            counter += baseline_object_LCC.totalCost
          end
        end
      end
      return counter
    end #end of def add_to_baseline_demo_cost_counter

    #reporting initial condition of model
    runner.registerInitialCondition("#{old_lights_def.name} is used #{old_lights_def.quantity} times in the model.")

    #add one time demo cost of removed lights
    if demo_cost_initial_const == true
      building = model.getBuilding
      lcc_baseline_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_baseline_demo", building, add_to_baseline_demo_cost_counter(old_lights_def, demo_cost_initial_const), "CostPerEach", "Salvage", 0, 0).get #using 0 for repeat period since one time cost.
      runner.registerInfo("Adding one time cost of $#{neat_numbers(lcc_baseline_demo.totalCost,0)} related to demolition of baseline objects.")
    end

    #array for lights to alter
    lights_to_swap = []

    #push space_type instances to the array
    space_types = model.getSpaceTypes
    space_types.each do |space_type|
      space_type_lights = space_type.lights
      space_type_spaces = space_type.spaces
      if space_type_spaces.size > 0
        space_type_lights.each do |space_type_light|
          if space_type_light.definition == old_lights_def
            lights_to_swap << space_type_light
          end
        end
      end
    end

    #push space_type instances to the array
    spaces = model.getSpaceTypes
    spaces.each do |space|
      space_lights = space.lights
      space_lights.each do |space_light|
        if space_light.definition == old_lights_def
          lights_to_swap << space_light
        end
      end
    end

    #flag for non-1 instance multiplier
    non_1_multiplier = false

    #swap definitions
    lights_to_swap.each do |light|
      #apply requested definition
      light.setLightsDefinition(new_lights_def)
      #set flag for non-1 multiplier in instance
      non_1_multiplier = true
    end

    #warn if non-1 multiplier in instance
    if non_1_multiplier == true
      runner.registerInfo("One or more light instances have a non 1 multiplier.")
    end

    #reporting final condition of model
    runner.registerFinalCondition("#{old_lights_def.name} is used #{old_lights_def.instances.size} times in the model.")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
SwapLightsDefinition.new.registerWithApplication