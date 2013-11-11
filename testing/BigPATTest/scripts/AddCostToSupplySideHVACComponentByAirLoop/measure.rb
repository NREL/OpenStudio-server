#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class AddCostToSupplySideHVACComponentByAirLoop < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "AddCostToSupplySideHVACComponentByAirLoop"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for constructions that are applied to surfaces in the model
    loop_handles = OpenStudio::StringVector.new
    loop_display_names = OpenStudio::StringVector.new

    #make an argument for the electric tariff
    hvac_comp_type_chs = OpenStudio::StringVector.new
    hvac_comp_type_chs << "CoilCoolingDXSingleSpeed"
    hvac_comp_type_chs << "CoilCoolingDXTwoSpeed"
    hvac_comp_type_chs << "CoilHeatingDXSingleSpeed"
    hvac_comp_type_chs << "CoilHeatingElectric"
    hvac_comp_type_chs << "CoilHeatingGas"
    hvac_comp_type_chs << "CoilHeatingWaterBaseboard"
    hvac_comp_type_chs << "FanConstantVolume"
    hvac_comp_type_chs << "FanOnOff"
    hvac_comp_type_chs << "FanVariableVolume"
    hvac_comp_type_chs << "PumpConstantSpeed"
    hvac_comp_type_chs << "PumpVariableSpeed"
    hvac_comp_type_chs << "CoilCoolingWater"
    hvac_comp_type_chs << "CoilHeatingWater"
    hvac_comp_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('hvac_comp_type', hvac_comp_type_chs, true)
    hvac_comp_type.setDisplayName("Select an HVAC Air Loop Supply Side Component Type.")
    args << hvac_comp_type
       
    #putting space types and names into hash
    loop_args = model.getAirLoopHVACs
    loop_args_hash = {}
    loop_args.each do |loop_arg|
      loop_args_hash[loop_arg.name.to_s] = loop_arg
    end

    #looping through sorted hash of air loops
    loop_args_hash.sort.map do |key,value|
      show_loop = false
      components = value.demandComponents
      components.each do |component|
        if component.to_CoilCoolingDXTwoSpeed.empty?
          show_loop = true
        end
      end
      if show_loop == true
        loop_handles << value.handle.to_s
        loop_display_names << key
      end
    end

    #add building to string vector with air loops
    building = model.getBuilding
    loop_handles << building.handle.to_s
    loop_display_names << "*All Air Loops*"

    #make an argument for air loops
    object = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("object", loop_handles, loop_display_names,true)
    object.setDisplayName("Choose an Air Loop to Add Costs to.")
    object.setDefaultValue("**All Air Loops**") #if no air loop is chosen this will run on all air loops
    args << object

    #make an argument to remove existing costs
    remove_costs = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_costs",true)
    remove_costs.setDisplayName("Remove Existing Costs?")
    remove_costs.setDefaultValue(true)
    args << remove_costs

    #make an argument for material and installation cost
    material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("material_cost",true)
    material_cost.setDisplayName("Material and Installation Costs per Component ($).")
    material_cost.setDefaultValue(0.0)
    args << material_cost

    #make an argument for demolition cost
    demolition_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("demolition_cost",true)
    demolition_cost.setDisplayName("Demolition Costs per Component ($).")
    demolition_cost.setDefaultValue(0.0)
    args << demolition_cost

    #make an argument for duration in years until costs start
    years_until_costs_start = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("years_until_costs_start",true)
    years_until_costs_start.setDisplayName("Years Until Costs Start (whole years).")
    years_until_costs_start.setDefaultValue(0)
    args << years_until_costs_start

    #make an argument to determine if demolition costs should be included in initial construction
    demo_cost_initial_const = OpenStudio::Ruleset::OSArgument::makeBoolArgument("demo_cost_initial_const",true)
    demo_cost_initial_const.setDisplayName("Demolition Costs Occur During Initial Construction?")
    demo_cost_initial_const.setDefaultValue(false)
    args << demo_cost_initial_const

    #make an argument for expected life
    expected_life = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("expected_life",true)
    expected_life.setDisplayName("Expected Life (whole years).")
    expected_life.setDefaultValue(20)
    args << expected_life

    #make an argument for o&m cost
    om_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("om_cost",true)
    om_cost.setDisplayName("O & M Costs per Component ($).")
    om_cost.setDefaultValue(0.0)
    args << om_cost

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
    object = runner.getOptionalWorkspaceObjectChoiceValue("object",user_arguments,model) #model is passed in because of argument type
    hvac_comp_type = runner.getStringArgumentValue("hvac_comp_type",user_arguments)
    remove_costs = runner.getBoolArgumentValue("remove_costs",user_arguments)
    material_cost = runner.getDoubleArgumentValue("material_cost",user_arguments)
    demolition_cost = runner.getDoubleArgumentValue("demolition_cost",user_arguments)
    years_until_costs_start = runner.getIntegerArgumentValue("years_until_costs_start",user_arguments)
    demo_cost_initial_const = runner.getBoolArgumentValue("demo_cost_initial_const",user_arguments)
    expected_life = runner.getIntegerArgumentValue("expected_life",user_arguments)
    om_cost = runner.getDoubleArgumentValue("om_cost",user_arguments)
    om_frequency = runner.getIntegerArgumentValue("om_frequency",user_arguments)
    
    #check the loop for reasonableness
    apply_to_all_loops = false
    loop = nil
    if object.empty?
      handle = runner.getStringArgumentValue("loop",user_arguments)
      if handle.empty?
        runner.registerError("No air loop was chosen.")
      else
        runner.registerError("The selected loop with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not object.get.to_AirLoopHVAC.empty?
        loop = object.get.to_AirLoopHVAC.get
      elsif not object.get.to_Building.empty?
        apply_to_all_loops = true
      else
        runner.registerError("Script Error - argument not showing up as air loop.")
        return false
      end
    end  #end of if loop.empty?

    #set flags to use later
    costs_requested = false
    costs_removed = false

    #check costs for reasonableness
    if material_cost.abs + demolition_cost.abs + om_cost.abs == 0
      runner.registerInfo("No costs were requested for Coil Cooling DX Two Speed units on #{loop.name}.")
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

    #helper that loops through lifecycle costs getting total costs under "Construction" or "Salvage" category and add to counter if occurs during year 0
    def get_total_costs_for_objects(objects)
      counter = 0
      objects.each do |object|
        object_LCCs = object.lifeCycleCosts
        object_LCCs.each do |object_LCC|
          if object_LCC.category == "Construction" or object_LCC.category == "Salvage"
            if object_LCC.yearsFromStart == 0
              counter += object_LCC.totalCost
            end
          end
        end
      end
      return counter
    end #end of def get_total_costs_for_objects(objects)

    #get air loops for measure
    if apply_to_all_loops
      loops = model.getAirLoopHVACs
    else
      loops = []
      loops << loop #only run on a single space type
    end

    #find components of requested type on requested air loop(s) and push to hVACComponents array
    hVACComponents = []
    loops.each do |loop|
      counter = hVACComponents.size
      components = loop.supplyComponents
      components.each do |component|
        if not component.to_CoilCoolingDXSingleSpeed.empty? and hvac_comp_type == "CoilCoolingDXSingleSpeed"
          hVACComponents << component
        elsif not component.to_CoilCoolingDXTwoSpeed.empty? and hvac_comp_type == "CoilCoolingDXTwoSpeed"
          hVACComponents << component
        elsif not component.to_CoilHeatingDXSingleSpeed.empty? and hvac_comp_type == "CoilHeatingDXSingleSpeed"
          hVACComponents << component
        elsif not component.to_CoilHeatingElectric.empty? and hvac_comp_type == "CoilHeatingElectric"
          hVACComponents << component
        elsif not component.to_CoilHeatingGas.empty? and hvac_comp_type == "CoilHeatingGas"
          hVACComponents << component
        elsif not component.to_CoilHeatingWaterBaseboard.empty? and hvac_comp_type == "CoilHeatingWaterBaseboard"
          hVACComponents << component
        elsif not component.to_FanConstantVolume.empty? and hvac_comp_type == "FanConstantVolume"
          hVACComponents << component
        elsif not component.to_FanOnOff.empty? and hvac_comp_type == "FanOnOff"
          hVACComponents << component
        elsif not component.to_FanVariableVolume.empty? and hvac_comp_type == "FanVariableVolume"
          hVACComponents << component
        elsif not component.to_PumpConstantSpeed.empty? and hvac_comp_type == "PumpConstantSpeed"
          hVACComponents << component
        elsif not component.to_PumpVariableSpeed.empty? and hvac_comp_type == "PumpVariableSpeed"
          hVACComponents << component
        elsif not component.to_CoilCoolingWater.empty? and hvac_comp_type == "CoilCoolingWater"
          hVACComponents << component
        elsif not component.to_CoilHeatingWater.empty? and hvac_comp_type == "CoilHeatingWater"
          hVACComponents << component
        end
      end #end of components.each do

      if counter == hVACComponents.size
        runner.registerWarning("#{loop.name} doesn't have any #{hvac_comp_type} components.")
      end
    end #end of loops.each do

    #get initial year 0 cost
    yr0_capital_totalCosts = get_total_costs_for_objects(hVACComponents)
    
    #reporting initial condition of model
    runner.registerInitialCondition("There are #{hVACComponents.size} #{hvac_comp_type} objects in the selected air loops. Capital costs for these components is $#{neat_numbers(yr0_capital_totalCosts,0)}.")

    #loop through hVACComponents to add life cycle costs
    hVACComponents.each do |hVACComponent|

      #remove any component cost line items associated with the hVACComponent
      if hVACComponent.lifeCycleCosts.size > 0 and remove_costs == true
        runner.registerInfo("Removing existing lifecycle cost objects associated with #{hVACComponent.name}")
        removed_costs = hVACComponent.removeLifeCycleCosts()
        costs_removed = true
      end

      #add lifeCycleCost objects if there is a non-zero value in one of the cost arguments
      if costs_requested == true

        #adding new cost items
        lcc_mat = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Mat - #{hVACComponent.name}", hVACComponent, material_cost, "CostPerEach", "Construction", expected_life, years_until_costs_start)
        if demo_cost_initial_const
          lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{hVACComponent.name}", hVACComponent, demolition_cost, "CostPerEach", "Salvage", expected_life, years_until_costs_start)
        else
          lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{hVACComponent.name}", hVACComponent, demolition_cost, "CostPerEach", "Salvage", expected_life, years_until_costs_start+expected_life)
        end
        lcc_om = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_OM - #{hVACComponent.name}", hVACComponent, om_cost, "CostPerEach", "Maintenance", om_frequency, 0)

      end #end of costs_requested == true

    end #end of hVACComponents.each do

    #show as not applicable if no cost requested and if no costs removed
    if costs_requested == false and costs_removed == false
      runner.registerAsNotApplicable("No new lifecycle costs objects were requested, and no costs were deleted.")
    end

    #get final year 0 cost
    yr0_capital_totalCosts = get_total_costs_for_objects(hVACComponents)

    #reporting final condition of model
    if hVACComponents.size > 0
      runner.registerFinalCondition("There are #{hVACComponents.size} #{hvac_comp_type} objects in the selected air loops. Capital costs for these components is $#{neat_numbers(yr0_capital_totalCosts,0)}.")
    else
      runner.registerAsNotApplicable("There are no #{hvac_comp_type} objects in the selected air loops.")
    end
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AddCostToSupplySideHVACComponentByAirLoop.new.registerWithApplication