#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class AddCostPerFloorAreaToLights < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "AddCostPerFloorAreaToLights"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for lights_defs that are applied to surfaces in the model
    lights_def_handles = OpenStudio::StringVector.new
    lights_def_display_names = OpenStudio::StringVector.new

    #putting space types and names into hash
    lights_def_args = model.getLightsDefinitions
    lights_def_args_hash = {}
    lights_def_args.each do |lights_def_arg|
      lights_def_args_hash[lights_def_arg.name.to_s] = lights_def_arg
    end

    #looping through sorted hash of lights_defs
    lights_def_args_hash.sort.map do |key,value|
      #only include if lights_def is an lights_def, if it is used in a space, and is an LPD def
      if value.quantity > 0 and not value.wattsperSpaceFloorArea.empty?
        lights_def_handles << value.handle.to_s
        lights_def_display_names << key
      end
    end

    #make an argument for lights_def
    #todo update this to allow all LPD lights defs. Think about how we want to handle multiple lights instances in same space.
    lights_def = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("lights_def", lights_def_handles, lights_def_display_names,true)
    lights_def.setDisplayName("Choose a Watt per Area Lights Definition to Add Costs to.")
    args << lights_def

    #make an argument to remove exisiting costs
    remove_costs = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_costs",true)
    remove_costs.setDisplayName("Remove Existing Costs?")
    remove_costs.setDefaultValue(true)
    args << remove_costs

    #make an argument for material and installation cost
    material_cost_ip = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("material_cost_ip",true)
    material_cost_ip.setDisplayName("Material and Installation Costs for Definition per Floor Area ($/ft^2).")
    material_cost_ip.setDefaultValue(0.0)
    args << material_cost_ip

    #make an argument for demolition cost
    demolition_cost_ip = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("demolition_cost_ip",true)
    demolition_cost_ip.setDisplayName("Demolition Costs for Definition per Floor Area ($/ft^2).")
    demolition_cost_ip.setDefaultValue(0.0)
    args << demolition_cost_ip

    #make an argument for duration in years until costs start
    years_until_costs_start = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("years_until_costs_start",true)
    years_until_costs_start.setDisplayName("Years Until Costs Start (whole years).")
    years_until_costs_start.setDefaultValue(0)
    args << years_until_costs_start

    #make an argument to determine if demolition costs should be included in initial Definition
    demo_cost_initial_const = OpenStudio::Ruleset::OSArgument::makeBoolArgument("demo_cost_initial_const",true)
    demo_cost_initial_const.setDisplayName("Demolition Costs Occur During Initial Definition?")
    demo_cost_initial_const.setDefaultValue(false)
    args << demo_cost_initial_const

    #make an argument for expected life
    expected_life = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("expected_life",true)
    expected_life.setDisplayName("Expected Life (whole years).")
    expected_life.setDefaultValue(20)
    args << expected_life

    #make an argument for o&m cost
    om_cost_ip = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("om_cost_ip",true)
    om_cost_ip.setDisplayName("O & M Costs for Definition per Floor Area ($/ft^2).")
    om_cost_ip.setDefaultValue(0.0)
    args << om_cost_ip

    #make an argument for o&m frequency
    om_frequency = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("om_frequency",true)
    om_frequency.setDisplayName("O & M Frequency (whole years).")
    om_frequency.setDefaultValue(1)
    args << om_frequency

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
    lights_def = runner.getOptionalWorkspaceObjectChoiceValue("lights_def",user_arguments,model) #model is passed in because of argument type
    remove_costs = runner.getBoolArgumentValue("remove_costs",user_arguments)
    material_cost_ip = runner.getDoubleArgumentValue("material_cost_ip",user_arguments)
    demolition_cost_ip = runner.getDoubleArgumentValue("demolition_cost_ip",user_arguments)
    years_until_costs_start = runner.getIntegerArgumentValue("years_until_costs_start",user_arguments)
    demo_cost_initial_const = runner.getBoolArgumentValue("demo_cost_initial_const",user_arguments)
    expected_life = runner.getIntegerArgumentValue("expected_life",user_arguments)
    om_cost_ip = runner.getDoubleArgumentValue("om_cost_ip",user_arguments)
    om_frequency = runner.getIntegerArgumentValue("om_frequency",user_arguments)

    #check the Definition for reasonableness
    if lights_def.empty?
      handle = runner.getStringArgumentValue("lights_def",user_arguments)
      if handle.empty?
        runner.registerError("No Lights Definition was chosen.")
      else
        runner.registerError("The selected Lights Definition with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not lights_def.get.to_LightsDefinition.empty?
        lights_def = lights_def.get.to_LightsDefinition.get
      else
        runner.registerError("Script Error - argument not showing up as Lights Definition.")
        return false
      end
    end  #end of if lights_def.empty?

    #set flags to use later
    costs_requested = false
    costs_removed = false

    #check costs for reasonableness
    if material_cost_ip.abs + demolition_cost_ip.abs + om_cost_ip.abs == 0
      runner.registerInfo("No costs were requested for #{lights_def.name}.")
    else
      costs_requested = true
    end

    #check lifecycle arguments for reasonableness
    if not years_until_costs_start >= 0 and not years_until_costs_start <= expected_life
      runner.registerError("Years until costs start should be a non-negative integer less than Expected Life.")
    end
    if not expected_life >= 1 and not expected_life <= 100
      runner.registerError("Choose an integer greater than 0 and less than or equal to 100 for Expected Life.")
    end
    if not om_frequency >= 1
      runner.registerError("Choose an integer greater than 0 for O & M Frequency.")
    end

    #short def to make numbers pretty (converts 4125001.25641 to 4,125,001.26 or 4,125,001). The definition be called through this measure
    def neat_numbers(number, roundto = 2) #round to 0 or 2)
      if roundto == 2
        number = sprintf "%.2f", number
      else
        number = number.round
      end
      #regex to add commas
      number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
    end #end def neat_numbers

    #reporting initial condition of model
    runner.registerInitialCondition("Lights definition #{lights_def.name} has #{lights_def.lifeCycleCosts.size} lifecycle cost objects.")

    #remove any component cost line items associated with the construction.
    if lights_def.lifeCycleCosts.size > 0 and remove_costs == true
      runner.registerInfo("Removing existing lifecycle cost objects associated with #{lights_def.name}")
      removed_costs = lights_def.removeLifeCycleCosts()
      costs_removed = (not removed_costs.empty?)
    end

    #show as not applicable if no cost requested and if no costs removed
    if costs_requested == false and costs_removed == false
      runner.registerAsNotApplicable("No new lifecycle costs objects were requested, and no costs were deleted.")
    end

    #add lifeCycleCost objects if there is a non-zero value in one of the cost arguments
    if costs_requested == true

      #converting doubles to si values from ip
      material_cost_si = OpenStudio::convert(OpenStudio::Quantity.new(material_cost_ip, OpenStudio::createUnit("1/ft^2").get), OpenStudio::createUnit("1/m^2").get).get.value
      demolition_cost_si = OpenStudio::convert(OpenStudio::Quantity.new(demolition_cost_ip, OpenStudio::createUnit("1/ft^2").get), OpenStudio::createUnit("1/m^2").get).get.value
      om_cost_si = OpenStudio::convert(OpenStudio::Quantity.new(om_cost_ip, OpenStudio::createUnit("1/ft^2").get), OpenStudio::createUnit("1/m^2").get).get.value

      #adding new cost items
      lcc_mat = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Mat - #{lights_def.name}", lights_def, material_cost_si, "CostPerArea", "Construction", expected_life, years_until_costs_start)
      if demo_cost_initial_const
        lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{lights_def.name}", lights_def, demolition_cost_si, "CostPerArea", "Salvage", expected_life, years_until_costs_start)
      else
        lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{lights_def.name}", lights_def, demolition_cost_si, "CostPerArea", "Salvage", expected_life, years_until_costs_start+expected_life)
      end
      lcc_om = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_OM - #{lights_def.name}", lights_def, om_cost_si, "CostPerArea", "Maintenance", om_frequency, 0)

    end #end of costs_requested == true

    #loop through lifecycle costs getting total costs under "Construction"" category
    lights_def_LCCs = lights_def.lifeCycleCosts
    lights_def_total_mat_cost = 0
    lights_def_LCCs.each do |lights_def_LCC|
      if lights_def_LCC.category == "Construction"
        lights_def_total_mat_cost += lights_def_LCC.totalCost
      end
    end

    #reporting final condition of model
    if lights_def.lifeCycleCosts.size > 0
      costed_area_ip = OpenStudio::convert(OpenStudio::Quantity.new(lights_def.lifeCycleCosts[0].costedArea.get, OpenStudio::createUnit("m^2").get), OpenStudio::createUnit("ft^2").get).get.value
      runner.registerFinalCondition("A new lifecycle cost object was added to Lights Definition #{lights_def.name} with an area of #{neat_numbers(costed_area_ip,0)} (ft^2). Material and Installation costs are $#{neat_numbers(lights_def_total_mat_cost,0)}.")
    else
      runner.registerFinalCondition("There are no lifecycle cost objects associated with Lights Definition #{lights_def.name}.")
    end

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AddCostPerFloorAreaToLights.new.registerWithApplication