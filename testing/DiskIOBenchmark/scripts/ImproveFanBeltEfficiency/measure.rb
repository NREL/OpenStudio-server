#start the measure
class ImproveFanBeltEfficiency < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Improve Fan Belt Efficiency"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for constructions that are applied to surfaces in the model
    loop_handles = OpenStudio::StringVector.new
    loop_display_names = OpenStudio::StringVector.new

    #putting air loops and names into hash
    loop_args = model.getAirLoopHVACs
    loop_args_hash = {}
    loop_args.each do |loop_arg|
      loop_args_hash[loop_arg.name.to_s] = loop_arg
    end

    #looping through sorted hash of air loops
    loop_args_hash.sort.map do |key,value|
      show_loop = false
      components = value.supplyComponents
      components.each do |component|
        if not component.to_FanConstantVolume.empty?
          show_loop = true
        end
        if not component.to_FanVariableVolume.empty?
          show_loop = true
        end
        if not component.to_FanOnOff.empty?
          show_loop = true
        end
      end

      #if loop as object of correct type then add to hash.
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
    object.setDisplayName("Choose an Air Loop to Alter.")
    object.setDefaultValue("*All Air Loops*") #if no loop is chosen this will run on all air loops
    args << object

    #todo - change this to choice list from design document
    #make an argument to add new space true/false
    motor_eff = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("motor_eff",true)
    motor_eff.setDisplayName("Motor Efficiency Improvement Due to Fan Belt Improvements(%).")
    motor_eff.setDefaultValue(3.0)
    args << motor_eff

    #bool argument to remove existing costs
    remove_costs = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_costs",true)
    remove_costs.setDisplayName("Remove Baseline Costs From Effected Fans?")
    remove_costs.setDefaultValue(false)
    args << remove_costs

    #make an argument for material and installation cost
    material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("material_cost",true)
    material_cost.setDisplayName("Material and Installation Costs per Motor ($).")
    material_cost.setDefaultValue(0.0)
    args << material_cost

    #make an argument for demolition cost
    demolition_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("demolition_cost",true)
    demolition_cost.setDisplayName("Demolition Costs per Motor ($).")
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
    om_cost.setDisplayName("O & M Costs per Motor ($).")
    om_cost.setDefaultValue(0.0)
    args << om_cost

    #make an argument for o&m frequency
    om_frequency = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("om_frequency",true)
    om_frequency.setDisplayName("O & M Frequency (whole years).")
    om_frequency.setDefaultValue(1)
    args << om_frequency

    return args
  end #end the arguments method

  #define what happens when the measure is cop
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    object = runner.getOptionalWorkspaceObjectChoiceValue("object",user_arguments,model) #model is passed in because of argument type
    motor_eff = runner.getDoubleArgumentValue("motor_eff",user_arguments)
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
        runner.registerError("No loop was chosen.")
      else
        runner.registerError("The selected loop with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not object.get.to_Loop.empty?
        loop = object.get.to_Loop.get
      elsif not object.get.to_Building.empty?
        apply_to_all_loops = true
      else
        runner.registerError("Script Error - argument not showing up as loop.")
        return false
      end
    end  #end of if loop.empty?


    #check the user_name for reasonableness
    if motor_eff <= 1 or  motor_eff >= 5
      runner.registerWarning("Requested motor efficiency improvement is not between expected values of 1% and 5%")
    end
    # motor efficiency will be checked motor by motor to see warn if higher than 0.96 and error if not between or equal to 0 and 1

    #set flags to use later
    costs_requested = false

    #set values to use later
    yr0_capital_totalCosts_baseline = 0
    yr0_capital_totalCosts_proposed = 0

    #If demo_cost_initial_const is true then will be applied once in the lifecycle. Future replacements use the demo cost of the new construction.
    demo_costs_of_baseline_objects = 0

    #check costs for reasonableness
    if material_cost.abs + demolition_cost.abs + om_cost.abs == 0
      runner.registerInfo("No costs were requested for motors improvements.")
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

    #get loops for measure
    if apply_to_all_loops
      loops = model.getAirLoopHVACs
    else
      loops = []
      loops << loop #only run on a single space type
    end

    # get cop values
    initial_motor_efficiency_values = []
    missing_initial_motor_efficiency = 0

    #loop through air loops
    loops.each do |loop|
      supply_components = loop.supplyComponents

      #find fans on loop
      supply_components.each do |supply_component|
        hVACComponent = supply_component.to_FanConstantVolume
        if hVACComponent.empty?
          hVACComponent = supply_component.to_FanVariableVolume
        end
        if hVACComponent.empty?
          hVACComponent = supply_component.to_FanOnOff
        end

        #alter components of correct type
        if not hVACComponent.empty?
          hVACComponent = hVACComponent.get

          #change and report changes to fans and motors
          initial_motor_efficiency = hVACComponent.motorEfficiency
          target_motor_efficiency = initial_motor_efficiency + motor_eff * 0.01
          initial_motor_efficiency_values << initial_motor_efficiency
          if target_motor_efficiency > 1
            hVACComponent.setMotorEfficiency(1.0)
            runner.registerWarning("Requested efficiency of #{target_motor_efficiency*100}% for #{hVACComponent.name} is not possible. Setting motor efficiency to 100%.")
          elsif target_motor_efficiency < 0
            hVACComponent.setMotorEfficiency(0.0)
            runner.registerWarning("Requested efficiency of #{target_motor_efficiency*100}% for #{hVACComponent.name} is not possible. Setting motor efficiency to 0%.")
          else
            hVACComponent.setMotorEfficiency(target_motor_efficiency)
            runner.registerInfo("Changing the motor efficiency from #{initial_motor_efficiency*100}% to #{target_motor_efficiency*100}% for '#{hVACComponent.name}' onloop '#{loop.name}.'")
            if target_motor_efficiency > 0.96
            runner.registerWarning("Requested efficiency for #{hVACComponent.name} is greater than 96%.")
            end
          end

          #get initial year 0 cost
          yr0_capital_totalCosts_baseline += get_total_costs_for_objects([hVACComponent])

          #demo value of baseline costs associated with unit
          demo_LCCs = hVACComponent.lifeCycleCosts
          demo_LCCs.each do |demo_LCC|
            if demo_LCC.category == "Salvage"
              demo_costs_of_baseline_objects += demo_LCC.totalCost
            end
          end

          #remove all old costs
          if hVACComponent.lifeCycleCosts.size > 0 and remove_costs == true
            runner.registerInfo("Removing existing lifecycle cost objects associated with #{hVACComponent.name}")
            removed_costs = hVACComponent.removeLifeCycleCosts()
          end

          #add new costs
          if costs_requested == true

            #adding new cost items
            lcc_mat = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Mat - #{hVACComponent.name}", hVACComponent, material_cost, "CostPerEach", "Construction", expected_life, years_until_costs_start)
            # cost for if demo_initial_Construction == true is added at the end of the measure
            lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{hVACComponent.name}", hVACComponent, demolition_cost, "CostPerEach", "Salvage", expected_life, years_until_costs_start+expected_life)
            lcc_om = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_OM - #{hVACComponent.name}", hVACComponent, om_cost, "CostPerEach", "Maintenance", om_frequency, 0)

            #get final year 0 cost
            yr0_capital_totalCosts_proposed += get_total_costs_for_objects([hVACComponent])

          end #end of costs_requested == true

        end #end if not hVACComponent.empty?

      end #end supply_components.each do

    end #end loops.each do

    #add one time demo cost of removed windows if appropriate
    if demo_cost_initial_const == true
      building = model.getBuilding
      lcc_baseline_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_baseline_demo", building, demo_costs_of_baseline_objects, "CostPerEach", "Salvage", 0, years_until_costs_start).get #using 0 for repeat period since one time cost.
      runner.registerInfo("Adding one time cost of $#{neat_numbers(lcc_baseline_demo.totalCost,0)} related to demolition of baseline objects.")

      #if demo occurs on year 0 then add to initial capital cost counter
      if lcc_baseline_demo.yearsFromStart == 0
        yr0_capital_totalCosts_proposed += lcc_baseline_demo.totalCost
      end
    end

    #reporting initial condition of model
    runner.registerInitialCondition("The starting motor efficiency values in affected loop(s) range from #{initial_motor_efficiency_values.min*100}% to #{initial_motor_efficiency_values.max*100}%. Initial year 0 capital costs for affected fans is $#{neat_numbers(yr0_capital_totalCosts_baseline,0)}.")

    if initial_motor_efficiency_values.size + missing_initial_motor_efficiency == 0
      runner.registerAsNotApplicable("The affected loop(s) does not contain any fans, the model will not be altered.")
      return true
    end

    #reporting final condition of model
    runner.registerFinalCondition("#{initial_motor_efficiency_values.size + missing_initial_motor_efficiency} fans had motor efficiency values set to altered. Final year 0 capital costs for affected fans is $#{neat_numbers(yr0_capital_totalCosts_proposed,0)}.")

    return true

  end #end the cop method

end #end the measure

#this allows the measure to be used by the application
ImproveFanBeltEfficiency.new.registerWithApplication