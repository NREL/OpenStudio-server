#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class AddCostPerFloorAreaToElectricEquipment < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "AddCostPerFloorAreaToElectricEquipment"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for equip_defs that are applied to surfaces in the model
    equip_def_handles = OpenStudio::StringVector.new
    equip_def_display_names = OpenStudio::StringVector.new

    #putting space types and names into hash
    equip_def_args = model.getElectricEquipmentDefinitions
    equip_def_args_hash = {}
    equip_def_args.each do |equip_def_arg|
      equip_def_args_hash[equip_def_arg.name.to_s] = equip_def_arg
    end

    #looping through sorted hash of equip_defs
    equip_def_args_hash.sort.map do |key,value|
      #only include if equip_def is an equip_def, if it is used in a space, and is an LPD def
      if value.quantity > 0 and not value.wattsperSpaceFloorArea.empty?
        equip_def_handles << value.handle.to_s
        equip_def_display_names << key
      end
    end

    #make an argument for equip_def
    #todo update this to allow all LPD elec equipment defs. Think about how we want to handle multiple equipment instances in same space.
    equip_def = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("equip_def", equip_def_handles, equip_def_display_names,true)
    equip_def.setDisplayName("Choose a Watts per Area Electric Equipment Definition to Add Costs to.")
    args << equip_def

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
    equip_def = runner.getOptionalWorkspaceObjectChoiceValue("equip_def",user_arguments,model) #model is passed in because of argument type
    remove_costs = runner.getBoolArgumentValue("remove_costs",user_arguments)
    material_cost_ip = runner.getDoubleArgumentValue("material_cost_ip",user_arguments)
    demolition_cost_ip = runner.getDoubleArgumentValue("demolition_cost_ip",user_arguments)
    years_until_costs_start = runner.getIntegerArgumentValue("years_until_costs_start",user_arguments)
    demo_cost_initial_const = runner.getBoolArgumentValue("demo_cost_initial_const",user_arguments)
    expected_life = runner.getIntegerArgumentValue("expected_life",user_arguments)
    om_cost_ip = runner.getDoubleArgumentValue("om_cost_ip",user_arguments)
    om_frequency = runner.getIntegerArgumentValue("om_frequency",user_arguments)
    
    #check the Definition for reasonableness
    if equip_def.empty?
      handle = runner.getStringArgumentValue("equip_def",user_arguments)
      if handle.empty?
        runner.registerError("No Electric Equipment Definition was chosen.")
      else
        runner.registerError("The selected Electric Equipment Definition with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not equip_def.get.to_ElectricEquipmentDefinition.empty?
        equip_def = equip_def.get.to_ElectricEquipmentDefinition.get
      else
        runner.registerError("Script Error - argument not showing up as Electric Equipment Definition.")
        return false
      end
    end  #end of if equip_def.empty?

    #set flags to use later
    costs_requested = false
    costs_removed = false

    #check costs for reasonableness
    if material_cost_ip.abs + demolition_cost_ip.abs + om_cost_ip.abs == 0
      runner.registerInfo("No costs were requested for #{equip_def.name}.")
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
    runner.registerInitialCondition("Electric equipment definition #{equip_def.name} has #{equip_def.lifeCycleCosts.size} lifecycle cost objects.")

    #remove any component cost line items associated with the construction.
    if equip_def.lifeCycleCosts.size > 0 and remove_costs == true
      runner.registerInfo("Removing existing lifecycle cost objects associated with #{equip_def.name}")
      removed_costs = equip_def.removeLifeCycleCosts()
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
      lcc_mat = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Mat - #{equip_def.name}", equip_def, material_cost_si, "CostPerArea", "Construction", expected_life, years_until_costs_start)
      if demo_cost_initial_const
        lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{equip_def.name}", equip_def, demolition_cost_si, "CostPerArea", "Salvage", expected_life, years_until_costs_start)
      else
        lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{equip_def.name}", equip_def, demolition_cost_si, "CostPerArea", "Salvage", expected_life, years_until_costs_start+expected_life)
      end
      lcc_om = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_OM - #{equip_def.name}", equip_def, om_cost_si, "CostPerArea", "Maintenance", om_frequency, 0)

    end #end of costs_requested == true

    #loop through lifecycle costs getting total costs under "Construction category"
    equip_def_LCCs = equip_def.lifeCycleCosts
    equip_def_total_mat_cost = 0
    equip_def_LCCs.each do |equip_def_LCC|
      if equip_def_LCC.category == "Construction"
        equip_def_total_mat_cost += equip_def_LCC.totalCost
      end
    end

    #reporting final condition of model
    if equip_def.lifeCycleCosts.size > 0
      costed_area_ip = OpenStudio::convert(OpenStudio::Quantity.new(equip_def.lifeCycleCosts[0].costedArea.get, OpenStudio::createUnit("m^2").get), OpenStudio::createUnit("ft^2").get).get.value
      runner.registerFinalCondition("A new lifecycle cost object was added to Electric Equipment Definition #{equip_def.name} with an area of #{neat_numbers(costed_area_ip,0)} (ft^2). Material and Installation costs are $#{neat_numbers(equip_def_total_mat_cost,0)}.")
    else
      runner.registerFinalCondition("There are no lifecycle cost objects associated with Electric Equipment Definition #{equip_def.name}.")
    end
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AddCostPerFloorAreaToElectricEquipment.new.registerWithApplication