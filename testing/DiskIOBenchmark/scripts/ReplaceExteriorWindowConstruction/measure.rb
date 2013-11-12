#start the measure
class ReplaceExteriorWindowConstruction < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Replace Exterior Window Constructions with a Different Construction from the Model."
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make a choice argument for constructions that are appropriate for windows
    construction_handles = OpenStudio::StringVector.new
    construction_display_names = OpenStudio::StringVector.new

    #putting space types and names into hash
    construction_args = model.getConstructions
    construction_args_hash = {}
    construction_args.each do |construction_arg|
      construction_args_hash[construction_arg.name.to_s] = construction_arg
    end

    #looping through sorted hash of constructions
    construction_args_hash.sort.map do |key,value|
      #only include if construction is a valid fenestration construction
      if value.isFenestration
        construction_handles << value.handle.to_s
        construction_display_names << key
      end
    end

    #make a choice argument for fixed windows
    construction = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("construction", construction_handles, construction_display_names,true)
    construction.setDisplayName("Pick a Window Construction From the Model to Replace Existing Window Constructions.")
    args << construction

    #make a bool argument for fixed windows
    change_fixed_windows = OpenStudio::Ruleset::OSArgument::makeBoolArgument("change_fixed_windows",true)
    change_fixed_windows.setDisplayName("Change Fixed Windows?")
    change_fixed_windows.setDefaultValue(true)
    args << change_fixed_windows

    #make a bool argument for operable windows
    change_operable_windows = OpenStudio::Ruleset::OSArgument::makeBoolArgument("change_operable_windows",true)
    change_operable_windows.setDisplayName("Change Operable Windows?")
    change_operable_windows.setDefaultValue(true)
    args << change_operable_windows

    #make an argument to remove existing costs
    remove_costs = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_costs",true)
    remove_costs.setDisplayName("Remove Existing Costs?")
    remove_costs.setDefaultValue(true)
    args << remove_costs

    #make an argument for material and installation cost
    material_cost_ip = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("material_cost_ip",true)
    material_cost_ip.setDisplayName("Material and Installation Costs for Construction per Area Used ($/ft^2).")
    material_cost_ip.setDefaultValue(0.0)
    args << material_cost_ip

    #make an argument for demolition cost
    demolition_cost_ip = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("demolition_cost_ip",true)
    demolition_cost_ip.setDisplayName("Demolition Costs for Construction per Area Used ($/ft^2).")
    demolition_cost_ip.setDefaultValue(0.0)
    args << demolition_cost_ip

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
    om_cost_ip = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("om_cost_ip",true)
    om_cost_ip.setDisplayName("O & M Costs for Construction per Area Used ($/ft^2).")
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
    construction = runner.getOptionalWorkspaceObjectChoiceValue("construction",user_arguments,model)
    change_fixed_windows = runner.getBoolArgumentValue("change_fixed_windows",user_arguments)
    change_operable_windows = runner.getBoolArgumentValue("change_operable_windows",user_arguments)
    remove_costs = runner.getBoolArgumentValue("remove_costs",user_arguments)
    material_cost_ip = runner.getDoubleArgumentValue("material_cost_ip",user_arguments)
    demolition_cost_ip = runner.getDoubleArgumentValue("demolition_cost_ip",user_arguments)
    years_until_costs_start = runner.getIntegerArgumentValue("years_until_costs_start",user_arguments)
    demo_cost_initial_const = runner.getBoolArgumentValue("demo_cost_initial_const",user_arguments)
    expected_life = runner.getIntegerArgumentValue("expected_life",user_arguments)
    om_cost_ip = runner.getDoubleArgumentValue("om_cost_ip",user_arguments)
    om_frequency = runner.getIntegerArgumentValue("om_frequency",user_arguments)

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
    end  #end of if construction.empty?

    #set flags and counters to use later
    costs_requested = false
    costs_removed = false

    #Later will add hard sized $ cost to this each time I swap a construction surfaces.
    #If demo_cost_initial_const is true then will be applied once in the lifecycle. Future replacements use the demo cost of the new construction.
    demo_costs_of_baseline_objects = 0

    #check costs for reasonableness
    if material_cost_ip.abs + demolition_cost_ip.abs + om_cost_ip.abs == 0
      runner.registerInfo("No costs were requested for #{construction.name}.")
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

    #clone construction to get proper area for measure economics, in case it is used elsewhere in the building
    new_object = construction.clone(model)
    if not new_object.to_Construction.empty?
      construction = new_object.to_Construction.get
    end

    #remove any component cost line items associated with the construction.
    if construction.lifeCycleCosts.size > 0 and remove_costs == true
      runner.registerInfo("Removing existing lifecycle cost objects associated with #{construction.name}")
      removed_costs = construction.removeLifeCycleCosts()
      costs_removed = (not removed_costs.empty?)
    end

    removed_costs = construction.removeLifeCycleCosts()
    costs_removed = (not removed_costs.empty?)

    #add lifeCycleCost objects if there is a non-zero value in one of the cost arguments
    if costs_requested == true

      #converting doubles to si values from ip
      material_cost_si = OpenStudio::convert(OpenStudio::Quantity.new(material_cost_ip, OpenStudio::createUnit("1/ft^2").get), OpenStudio::createUnit("1/m^2").get).get.value
      demolition_cost_si = OpenStudio::convert(OpenStudio::Quantity.new(demolition_cost_ip, OpenStudio::createUnit("1/ft^2").get), OpenStudio::createUnit("1/m^2").get).get.value
      om_cost_si = OpenStudio::convert(OpenStudio::Quantity.new(om_cost_ip, OpenStudio::createUnit("1/ft^2").get), OpenStudio::createUnit("1/m^2").get).get.value

      #adding new cost items
      lcc_mat = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Mat-#{construction.name}", construction, material_cost_si, "CostPerArea", "Construction", expected_life, years_until_costs_start)
      # if demo_cost_initial_const is true then later will add one time demo costs using removed baseline objects. Cost will occur at year specified by years_until_costs_start
      lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo-#{construction.name}", construction, demolition_cost_si, "CostPerArea", "Salvage", expected_life, years_until_costs_start+expected_life)
      lcc_om = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_OM-#{construction.name}", construction, om_cost_si, "CostPerArea", "Maintenance", om_frequency, 0)

    end #end of costs_requested == true

    #loop through sub surfaces
    starting_exterior_windows_constructions = []
    sub_surfaces_to_change = []
    sub_surfaces = model.getSubSurfaces
    sub_surfaces.each do |sub_surface|
      if sub_surface.outsideBoundaryCondition == "Outdoors" and sub_surface.subSurfaceType == "FixedWindow" and change_fixed_windows == true
        sub_surfaces_to_change << sub_surface
        sub_surface_const = sub_surface.construction
        if not sub_surface_const.empty?
          if starting_exterior_windows_constructions.size == 0
            starting_exterior_windows_constructions << "#{sub_surface_const.get.name.to_s}"
          else
            starting_exterior_windows_constructions << "#{sub_surface_const.get.name.to_s}"
          end
        end
      elsif sub_surface.outsideBoundaryCondition == "Outdoors" and sub_surface.subSurfaceType == "OperableWindow" and change_operable_windows == true
        sub_surfaces_to_change << sub_surface
        sub_surface_const = sub_surface.construction
        if not sub_surface_const.empty?
          if starting_exterior_windows_constructions.size == 0
            starting_exterior_windows_constructions << "#{sub_surface_const.get.name.to_s}"
          else
            starting_exterior_windows_constructions << "#{sub_surface_const.get.name.to_s}"
          end
        end
      end #end of if for fixed and operable windows
    end #end of sub_surfaces.each do

    #create array of constructions for sub_surfaces to change, before construction is replaced
    constructions_to_change = []
    sub_surfaces_to_change.each do |sub_surface|
        if not sub_surface.construction.empty?
          constructions_to_change << sub_surface.construction.get
        end
    end

    #getting cost of all existing windows before constructions are swapped. This will create demo cost if all windows were removed. Will adjust later for windows left in place
    constructions_to_change.uniq.each do |construction_to_change|
      #loop through lifecycle costs getting total costs under "Salvage" category
      demo_LCCs = construction_to_change.lifeCycleCosts
      demo_LCCs.each do |demo_LCC|
        if demo_LCC.category == "Salvage"
          demo_costs_of_baseline_objects += demo_LCC.totalCost
        end
      end
    end

    if change_fixed_windows == false and change_operable_windows == false
      runner.registerAsNotApplicable("Fixed and operable windows are both set not to change.")
      return true #no need to waste time with the measure if we know it isn't applicable
    elsif sub_surfaces_to_change.size == 0
      runner.registerAsNotApplicable("There are no appropriate exterior windows to change in the model.")
      return true #no need to waste time with the measure if we know it isn't applicable
    end

    #report initial condition
    runner.registerInitialCondition("The building had #{starting_exterior_windows_constructions.uniq.size} window constructions: #{starting_exterior_windows_constructions.uniq.sort.join(", ")}.")

    #loop through construction sets used in the model
    default_construction_sets = model.getDefaultConstructionSets
    default_construction_sets.each do |default_construction_set|
      if default_construction_set.directUseCount > 0
        default_sub_surface_const_set = default_construction_set.defaultExteriorSubSurfaceConstructions
        if not default_sub_surface_const_set.empty?
          starting_construction = default_sub_surface_const_set.get.fixedWindowConstruction

          #creating new default construction set
          new_default_construction_set = default_construction_set.clone(model)
          new_default_construction_set = new_default_construction_set.to_DefaultConstructionSet.get

          #create new sub_surface set
          new_default_sub_surface_const_set = default_sub_surface_const_set.get.clone(model)
          new_default_sub_surface_const_set = new_default_sub_surface_const_set.to_DefaultSubSurfaceConstructions.get

          if change_fixed_windows == true
            #assign selected construction sub_surface set
            new_default_sub_surface_const_set.setFixedWindowConstruction(construction)
          end

          if change_operable_windows == true
            #assign selected construction sub_surface set
            new_default_sub_surface_const_set.setOperableWindowConstruction(construction)
          end

          #link new subset to new set
          new_default_construction_set.setDefaultExteriorSubSurfaceConstructions(new_default_sub_surface_const_set)

          #swap all uses of the old construction set for the new
          construction_set_sources = default_construction_set.sources
          construction_set_sources.each do |construction_set_source|
            building_source = construction_set_source.to_Building
            if not building_source.empty?
              building_source = building_source.get
              building_source.setDefaultConstructionSet(new_default_construction_set)
              next
            end
            #add SpaceType, BuildingStory, and Space if statements

          end #end of construction_set_sources.each do
        end #end of if not default_sub_surface_const_set.empty?
      end #end of if default_construction_set.directUseCount > 0
    end #end of loop through construction sets

    #loop through appropriate sub surfaces and change where there is a hard assigned construction
    sub_surfaces_to_change.each do |sub_surface|
      if not sub_surface.isConstructionDefaulted
        sub_surface.setConstruction(construction)
      end
    end    
    
    #loop through lifecycle costs getting total costs under "Salvage" category
    constructions_to_change.uniq.each do |construction_to_change|
      demo_LCCs = construction_to_change.lifeCycleCosts
      demo_LCCs.each do |demo_LCC|
        if demo_LCC.category == "Salvage"
          demo_costs_of_baseline_objects += demo_LCC.totalCost * -1 #this is to adjust demo cost down for original windows that were not changed
        end
      end
    end

    #loop through lifecycle costs getting total costs under "Construction" or "Salvage" category and add to counter if occurs during year 0
    const_LCCs = construction.lifeCycleCosts
    yr0_capital_totalCosts = 0
    const_LCCs.each do |const_LCC|
      if const_LCC.category == "Construction" or const_LCC.category == "Salvage"
        if const_LCC.yearsFromStart == 0
          yr0_capital_totalCosts += const_LCC.totalCost
        end
      end
    end

    #add one time demo cost of removed windows if appropriate
    if demo_cost_initial_const == true
      building = model.getBuilding
      lcc_baseline_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_baseline_demo", building, demo_costs_of_baseline_objects, "CostPerEach", "Salvage", 0, years_until_costs_start).get #using 0 for repeat period since one time cost.
      runner.registerInfo("Adding one time cost of $#{neat_numbers(lcc_baseline_demo.totalCost,0)} related to demolition of baseline objects.")

      #if demo occurs on year 0 then add to initial capital cost counter
      if lcc_baseline_demo.yearsFromStart == 0
        yr0_capital_totalCosts += lcc_baseline_demo.totalCost
      end
    end
    
    #ip construction area for reporting
    const_area_ip = OpenStudio::convert(OpenStudio::Quantity.new(construction.getNetArea, OpenStudio::createUnit("m^2").get), OpenStudio::createUnit("ft^2").get).get.value

    #get names from constructions to change
    const_names = []
    if constructions_to_change.size > 0
      constructions_to_change.uniq.sort.each do |const_name|
        const_names << const_name.name
      end
    end

    #need to format better. At first I did each do, but seems initial condition only reports the first one.
    runner.registerFinalCondition("#{neat_numbers(const_area_ip,0)} (ft^2) of existing windows of the types: #{const_names.join(", ")} were replaced by new #{construction.name} windows. Initial capital costs associated with the new windows are $#{neat_numbers(yr0_capital_totalCosts,0)}.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
ReplaceExteriorWindowConstruction.new.registerWithApplication
