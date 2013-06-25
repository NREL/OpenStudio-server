#start the measure
class SetLightingLoadsByLPD < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Set Lighting Loads by LPD"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make a choice argument for model objects
    space_type_handles = OpenStudio::StringVector.new
    space_type_display_names = OpenStudio::StringVector.new

    #putting model object and names into hash
    space_type_args = model.getSpaceTypes
    space_type_args_hash = {}
    space_type_args.each do |space_type_arg|
      space_type_args_hash[space_type_arg.name.to_s] = space_type_arg
    end

    #looping through sorted hash of model objects
    space_type_args_hash.sort.map do |key,value|
      #only include if space type is used in the model
      if value.spaces.size > 0
        space_type_handles << value.handle.to_s
        space_type_display_names << key
      end
    end

    #add building to string vector with space type
    building = model.getBuilding
    space_type_handles << building.handle.to_s
    space_type_display_names << "*Entire Building*"

    #make a choice argument for space type or entire building
    space_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("space_type", space_type_handles, space_type_display_names,true)
    space_type.setDisplayName("Apply the Measure to a Specific Space Type or to the Entire Model")
    space_type.setDefaultValue("*Entire Building*") #if no space type is chosen this will run on the entire building
    args << space_type

    #make an argument LPD
    lpd = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("lpd",true)
    lpd.setDisplayName("Lighting Power Density (W/ft^2)")
    lpd.setDefaultValue(1.0)
    args << lpd

    #make a choice argument for units
    units_display_names = OpenStudio::StringVector.new
    units_display_names << "CostPerArea"
    units = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("units", units_display_names)
    units.setDefaultValue("CostPerArea")
    units.setDisplayName("Cost Units")
    args << units

    #make an optional argument for baseline material cost
    baseline_material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("baseline_material_cost",false)
    baseline_material_cost.setDisplayName("Baseline Material Cost")
    args << baseline_material_cost

    #make an optional argument for proposed material cost
    proposed_material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_material_cost",false)
    proposed_material_cost.setDisplayName("Proposed Material Cost")
    args << proposed_material_cost

    #make an optional argument for baseline installation cost
    baseline_installation_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("baseline_installation_cost",false)
    baseline_installation_cost.setDisplayName("Baseline Installation Cost")
    args << baseline_installation_cost

    #make an optional argument for proposed installation cost
    proposed_installation_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_installation_cost",false)
    proposed_installation_cost.setDisplayName("Proposed Installation Cost")
    args << proposed_installation_cost

    #make an optional argument for baseline demolition cost
    baseline_demolition_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("baseline_demolition_cost",false)
    baseline_demolition_cost.setDisplayName("Baseline Demolition Cost")
    args << baseline_demolition_cost

    #make an optional argument for proposed demolition cost
    proposed_demolition_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_demolition_cost",false)
    proposed_demolition_cost.setDisplayName("Proposed Demolition Cost")
    args << proposed_demolition_cost

    #make an optional argument for baseline salvage value
    baseline_salvage_value = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("baseline_salvage_value",false)
    baseline_salvage_value.setDisplayName("Baseline Salvage Value")
    args << baseline_salvage_value

    #make an optional argument for proposed salvage value
    proposed_salvage_value = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_salvage_value",false)
    proposed_salvage_value.setDisplayName("Proposed Salvage Value")
    args << proposed_salvage_value

    #make an optional argument for baseline recurring cost
    baseline_recurring_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("baseline_recurring_cost",false)
    baseline_recurring_cost.setDisplayName("Baseline Recurring Cost")
    args << baseline_recurring_cost

    #make an optional argument for proposed recurring cost
    proposed_recurring_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_recurring_cost",false)
    proposed_recurring_cost.setDisplayName("Proposed Recurring Cost")
    args << proposed_recurring_cost

    #make an optional argument for recurring cost frequency
    recurring_cost_frequency = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("recurring_cost_frequency",false)
    recurring_cost_frequency.setDisplayName("Recurring Cost Frequency")
    args << recurring_cost_frequency

    #make an optional argument for expected life
    expected_life = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("expected_life",false)
    expected_life.setDisplayName("Expected Life")
    args << expected_life

    #make a choice argument for retrofit or new construction
    retrofit_display_names = OpenStudio::StringVector.new
    retrofit_display_names << "New Construction"
    retrofit_display_names << "Retrofit"
    retrofit = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("retrofit", retrofit_display_names)
    retrofit.setDefaultValue("New Construction")
    retrofit.setDisplayName("Retrofit or New Construction")
    args << retrofit

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
    object = runner.getOptionalWorkspaceObjectChoiceValue("space_type",user_arguments,model)
    lpd = runner.getDoubleArgumentValue("lpd",user_arguments)
    units = runner.getStringArgumentValue("units",user_arguments)
    baseline_material_cost = runner.getOptionalDoubleArgumentValue("baseline_material_cost",user_arguments)
    baseline_installation_cost = runner.getOptionalDoubleArgumentValue("baseline_installation_cost",user_arguments)
    baseline_demolition_cost = runner.getOptionalDoubleArgumentValue("baseline_demolition_cost",user_arguments)
    baseline_salvage_value = runner.getOptionalDoubleArgumentValue("baseline_salvage_value",user_arguments)
    baseline_recurring_cost = runner.getOptionalDoubleArgumentValue("baseline_recurring_cost",user_arguments)
    proposed_material_cost = runner.getOptionalDoubleArgumentValue("proposed_material_cost",user_arguments)
    proposed_installation_cost = runner.getOptionalDoubleArgumentValue("proposed_installation_cost",user_arguments)
    proposed_demolition_cost = runner.getOptionalDoubleArgumentValue("proposed_demolition_cost",user_arguments)
    proposed_salvage_value = runner.getOptionalDoubleArgumentValue("proposed_salvage_value",user_arguments)
    proposed_recurring_cost = runner.getOptionalDoubleArgumentValue("proposed_recurring_cost",user_arguments)
    recurring_cost_frequency = runner.getOptionalIntegerArgumentValue("recurring_cost_frequency",user_arguments)
    expected_life = runner.getOptionalIntegerArgumentValue("expected_life",user_arguments)
    retrofit = runner.getStringArgumentValue("retrofit",user_arguments)

    #setup OpenStudio units that we will need
    unit_lpd_ip = OpenStudio::createUnit("W/ft^2").get
    unit_lpd_si = OpenStudio::createUnit("W/m^2").get
    unit_cost_per_area_ip = OpenStudio::createUnit("1/ft^2").get #$/ft^2 does not work
    unit_cost_per_area_si = OpenStudio::createUnit("1/m^2").get
    unit_area_ip = OpenStudio::createUnit("ft^2").get
    unit_area_si = OpenStudio::createUnit("m^2").get

    #define starting units
    lpd_ip = OpenStudio::Quantity.new(lpd, unit_lpd_ip)

    #unit conversion of lpd from IP units (W/ft^2) to SI units (W/m^2)
    lpd_si = OpenStudio::convert(lpd_ip, unit_lpd_si).get

    #check the space_type for reasonableness and see if measure should run on space type or on the entire building
    apply_to_building = false
    space_type = nil
    if object.empty?
      handle = runner.getStringArgumentValue("space_type",user_arguments)
      if handle.empty?
        runner.registerError("No SpaceType was chosen.")
      else
        runner.registerError("The selected space type with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not object.get.to_SpaceType.empty?
        space_type = object.get.to_SpaceType.get
      elsif not object.get.to_Building.empty?
        apply_to_building = true
        #space_type = model.getSpaceTypes
      else
        runner.registerError("Script Error - argument not showing up as space type or building.")
        return false
      end
    end

    #get optional values for baseline_material_cost, check for reasonablness, and convert to SI
    if not baseline_material_cost.empty?
      if not baseline_material_cost.get < 0
        baseline_material_cost_ip = OpenStudio::Quantity.new(baseline_material_cost.get, unit_cost_per_area_ip)
        baseline_material_cost_si = OpenStudio::convert(baseline_material_cost_ip, unit_cost_per_area_si).get
      else
        runner.registerError("Leave Baseline Material Cost blank or enter a non-negative number.")
        return false
      end
    else
      baseline_material_cost_si = 0
    end

    #get optional values for proposed_material_cost, check for reasonablness, and convert to SI
    if not proposed_material_cost.empty?
      if not proposed_material_cost.get < 0
        proposed_material_cost_ip = OpenStudio::Quantity.new(proposed_material_cost.get, unit_cost_per_area_ip)
        proposed_material_cost_si = OpenStudio::convert(proposed_material_cost_ip, unit_cost_per_area_si).get
      else
        runner.registerError("Leave Proposed Material Cost blank or enter a non-negative number.")
        return false
      end
    else
      proposed_material_cost_si = 0
    end

    #get optional values for baseline_installation_cost, check for reasonablness, and convert to SI
    if not baseline_installation_cost.empty?
      if not baseline_installation_cost.get < 0
        baseline_installation_cost_ip = OpenStudio::Quantity.new(baseline_installation_cost.get, unit_cost_per_area_ip)
        baseline_installation_cost_si = OpenStudio::convert(baseline_installation_cost_ip, unit_cost_per_area_si).get
      else
        runner.registerError("Leave Baseline Installation Cost blank or enter a non-negative number.")
        return false
      end
    else
      baseline_installation_cost_si = 0
    end

    #get optional values for proposed_installation_cost, check for reasonablness, and convert to SI
    if not proposed_installation_cost.empty?
      if not proposed_installation_cost.get < 0
        proposed_installation_cost_ip = OpenStudio::Quantity.new(proposed_installation_cost.get, unit_cost_per_area_ip)
        proposed_installation_cost_si = OpenStudio::convert(proposed_installation_cost_ip, unit_cost_per_area_si).get
      else
        runner.registerError("Leave Proposed Installation Cost blank or enter a non-negative number.")
        return false
      end
    else
      proposed_installation_cost_si = 0
    end

    #get optional values for baseline_demolition_cost, check for reasonablness, and convert to SI
    if not baseline_demolition_cost.empty?
      if not baseline_demolition_cost.get < 0
        baseline_demolition_cost_ip = OpenStudio::Quantity.new(baseline_demolition_cost.get, unit_cost_per_area_ip)
        baseline_demolition_cost_si = OpenStudio::convert(baseline_demolition_cost_ip, unit_cost_per_area_si).get
      else
        runner.registerError("Leave Baseline Demolition Cost blank or enter a non-negative number.")
        return false
      end
    else
      baseline_demolition_cost_si = 0
    end

    #get optional values for proposed_demolition_cost, check for reasonablness, and convert to SI
    if not proposed_demolition_cost.empty?
      if not proposed_demolition_cost.get < 0
        proposed_demolition_cost_ip = OpenStudio::Quantity.new(proposed_demolition_cost.get, unit_cost_per_area_ip)
        proposed_demolition_cost_si = OpenStudio::convert(proposed_demolition_cost_ip, unit_cost_per_area_si).get
      else
        runner.registerError("Leave Proposed Demolition Cost blank or enter a non-negative number.")
        return false
      end
    else
      proposed_demolition_cost_si = 0
    end

    #get optional values for baseline_salvage_value, check for reasonablness, and convert to SI
    if not baseline_salvage_value.empty?
      if not baseline_salvage_value.get < 0
        baseline_salvage_value_ip = OpenStudio::Quantity.new(baseline_salvage_value.get, unit_cost_per_area_ip)
        baseline_salvage_value_si = OpenStudio::convert(baseline_salvage_value_ip, unit_cost_per_area_si).get
      else
        runner.registerError("Leave Baseline Salvage Value blank or enter a non-negative number.")
        return false
      end
    else
      baseline_salvage_value_si = 0
    end

    #get optional values for proposed_salvage_value, check for reasonablness, and convert to SI
    if not proposed_salvage_value.empty?
      if not proposed_salvage_value.get < 0
        proposed_salvage_value_ip = OpenStudio::Quantity.new(proposed_salvage_value.get, unit_cost_per_area_ip)
        proposed_salvage_value_si = OpenStudio::convert(proposed_salvage_value_ip, unit_cost_per_area_si).get
      else
        runner.registerError("Leave Proposed Salvage Value blank or enter a non-negative number.")
        return false
      end
    else
      proposed_salvage_value_si = 0
    end

    #get optional values for baseline_recurring_cost, check for reasonablness, and convert to SI
    if not baseline_recurring_cost.empty?
      if not baseline_recurring_cost.get < 0
        baseline_recurring_cost_ip = OpenStudio::Quantity.new(baseline_recurring_cost.get, unit_cost_per_area_ip)
        baseline_recurring_cost_si = OpenStudio::convert(baseline_recurring_cost_ip, unit_cost_per_area_si).get
      else
        runner.registerError("Leave Baseline Recurring Cost blank or enter a non-negative number.")
        return false
      end
    else
      baseline_recurring_cost_si = 0
    end

    #get optional values for proposed_recurring_cost, check for reasonablness, and convert to SI
    if not proposed_recurring_cost.empty?
      if not proposed_recurring_cost.get < 0
        proposed_recurring_cost_ip = OpenStudio::Quantity.new(proposed_recurring_cost.get, unit_cost_per_area_ip)
        proposed_recurring_cost_si = OpenStudio::convert(proposed_recurring_cost_ip, unit_cost_per_area_si).get
      else
        runner.registerError("Leave Baseline Recurring Cost blank or enter a non-negative number.")
        return false
      end
    else
      proposed_recurring_cost_si = 0
    end

    #get optional values for expected_life, check for reasonablness, and convert to SI
    if not expected_life.empty?
      if not expected_life.get < 1
        expected_life = expected_life.get
      else
        runner.registerError("Leave Expected Life blank or enter an integer greater than or equal to 1.")
        return false
      end
    else
      #leave empty, reprepsents an infinite expected life
    end

    #check to see if the user included any cost in their arguments
    cost_included = false
    if not baseline_material_cost_si == 0 then cost_included = true end
    if not proposed_material_cost_si == 0 then cost_included = true end
    if not baseline_installation_cost_si == 0 then cost_included = true end
    if not proposed_installation_cost_si == 0 then cost_included = true end
    if not baseline_demolition_cost_si == 0 then cost_included = true end
    if not proposed_demolition_cost_si == 0 then cost_included = true end
    if not baseline_salvage_value_si == 0 then cost_included = true end
    if not proposed_salvage_value_si == 0 then cost_included = true end
    if not baseline_recurring_cost_si == 0 then cost_included = true end
    if not proposed_recurring_cost_si == 0 then cost_included = true end

    #short def to make numbers pretty (converts 4125001.25641 to 4,125,001.26 or 4,125,001). The definition be called through this measure
    def pretty_numbers(number, roundto = 2) #round to 0 or 2)
      # round to zero or two decimails
      if roundto == 2
        number = sprintf "%.2f", number
      else
        number = number.round
      end
      #regex to add commas
      number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
    end #end def pretty_numbers

    #report initial condition
    building = model.getBuilding
    building_start_lpd_si = OpenStudio::Quantity.new(building.lightingPowerPerFloorArea, unit_lpd_si)
    building_start_lpd_ip = OpenStudio::convert(building_start_lpd_si, unit_lpd_ip).get
    runner.registerInitialCondition("The model's initial LPD is #{building_start_lpd_ip}.")
    #Initial Condition: The building has an overall average LPD of $INITIAL_LPD$ W/ft^2.

    affected_area = 0
    capital_cost_per_area = 0

    #add if statement for NA if LPD = 0
    if not building_start_lpd_ip.value > 0
      runner.registerAsNotApplicable("The model has no lights, nothing will be changed.")
    end

    # create a new LightsDefinition and new Lights object to use with setLightingPowerPerFloorArea
    template_light_def = OpenStudio::Model::LightsDefinition.new(model)
    template_light_def.setName("LPD #{lpd_ip} - LightsDef")
    template_light_def.setWattsperSpaceFloorArea(lpd_si.value)

    template_light_inst = OpenStudio::Model::Lights.new(template_light_def)
    template_light_inst.setName("LPD #{lpd_ip} - LightsInstance")

    #get space types in model
    if apply_to_building
      space_types = model.getSpaceTypes
    else
      space_types = []
      space_types << space_type #only run on a single space type
    end

    #loop through space types
    space_types.each do |space_type|
      space_type_lights = space_type.lights
      space_type_spaces = space_type.spaces
      multiple_schedules = false

      space_type_lights_array = []

      #if space type has lights and is used in the model
      if space_type_lights.size > 0 and space_type_spaces.size > 0

        space_type_spaces.each do |space|
          thermal_zone = space.thermalZone
          if(thermal_zone)
            multiplier = thermal_zone.get.multiplier
          else
            multiplier = 1
          end
          affected_area = affected_area + space.floorArea * multiplier
        end

        lights_schedules = []
        space_type_lights.each do |space_type_light|
          lights_data_for_array = []
          if not space_type_light.schedule.empty?
            space_type_light_new_schedule =  space_type_light.schedule
            if not space_type_light_new_schedule.empty?
              lights_schedules << space_type_light_new_schedule.get
              if not space_type_light.powerPerFloorArea.empty?
                lights_data_for_array << space_type_light.powerPerFloorArea.get
              else
                lights_data_for_array << 0.0
              end
              lights_data_for_array << space_type_light_new_schedule.get
              lights_data_for_array << space_type_light.isScheduleDefaulted
              space_type_lights_array << lights_data_for_array
            end
          end
        end

        # pick schedule to use and see if it is defaulted
        space_type_lights_array = space_type_lights_array.sort.reverse[0]
        if not space_type_lights_array == nil #this is need if schedule is empty but also not defaulted
          if not space_type_lights_array[2] == true #if not schedule defaulted
            preferred_schedule = space_type_lights_array[1]
          else
            #leave schedule blank, it is defaulted
          end
        end

        # flag if lights_schedules has more than one unique object
        if lights_schedules.uniq.size > 1
          multiple_schedules = true
        end

        #delete lights and luminaires and add in new light.
        space_type_lights = space_type.lights
        space_type_luminaires = space_type.luminaires
        space_type_lights.each do |space_type_light|
          space_type_light.remove
        end
        space_type_luminaires.each do |space_type_luminaire|
          space_type_luminaire.remove
        end
        space_type_light_new = template_light_inst.clone(model)
        space_type_light_new = space_type_light_new.to_Lights.get
        space_type_light_new.setSpaceType(space_type)

        #only add component cost line item objects if the user entered some non 0 cost values
        if cost_included

          # creating componentCostLineItem
          ccli = OpenStudio::Model::ComponentCostLineItem.new(space_type_light_new)
          ccli.setMaterialCost(proposed_material_cost_si.value - baseline_material_cost_si.value)
          ccli.setMaterialCost(proposed_installation_cost_si.value - baseline_installation_cost_si.value)
          ccli.setDemolitionCost(proposed_demolition_cost_si.value - baseline_demolition_cost_si.value)
          ccli.setSalvageValue(proposed_salvage_value_si.value - baseline_salvage_value_si.value)
          crc = ccli.addComponentRecurringCost("ComponentRecurringCost","Maintenance",proposed_recurring_cost.get - baseline_recurring_cost.get,units)
          ccli.setExpectedLife(expected_life)

          ccli.setMaterialCostUnits(units)
          ccli.setInstallationCostUnits(units)
          ccli.setDemolitionCostUnits(units)
          ccli.setSalvageValueUnits(units)

          capital_cost_per_area = capital_cost_per_area + ccli.materialCost.get
          capital_cost_per_area = capital_cost_per_area + ccli.installationCost.get

          if(retrofit == "Retrofit")
            # creating second componentCostLineItem with infinite life
            retrofit_ccli = OpenStudio::Model::ComponentCostLineItem.new(space_type_light_new)
            retrofit_ccli.setMaterialCost(baseline_material_cost_si.value - baseline_salvage_value_si.value)
            retrofit_ccli.setInstallationCost(baseline_installation_cost_si.value + baseline_demolition_cost_si.value)
            retrofit_ccli.setMaterialCostUnits(units)
            retrofit_ccli.setInstallationCostUnits(units)

            capital_cost_per_area = capital_cost_per_area + ccli.materialCost.get
            capital_cost_per_area = capital_cost_per_area + ccli.installationCost.get
          end

        end

        #assign preferred schedule to new lights object
        if not space_type_light_new.schedule.nil? and not space_type_lights_array[2] == true
          space_type_light_new.setSchedule(preferred_schedule)
        else
          runner.registerWarning("No schedule is associated with the new lights object in space type #{space_type.name}.")          
        end

        #if schedules had to be removed due to multiple lights add warning
        if not space_type_light_new.schedule.nil? and multiple_schedules == true
          space_type_light_new_schedule = space_type_light_new.schedule
          runner.registerWarning("The space type named '#{space_type.name.to_s}' had more than one light object with unique schedules. The schedule named '#{space_type_light_new_schedule.get.name.to_s}' was used for the new LPD light object.")
        end

      elsif space_type_lights.size == 0 and space_type_spaces.size > 0
        runner.registerInfo("The space type named '#{space_type.name.to_s}' doesn't have any lights, none will be added.")
      end #end if space type has lights

    end #end space types each do

    #getting spaces in the model
    spaces = model.getSpaces

    #get space types in model
    if apply_to_building
      spaces = model.getSpaces
    else
      if not space_type.spaces.empty?
        spaces = space_type.spaces #only run on a single space type
      end
    end

    spaces.each do |space|
      space_lights = space.lights
      space_luminaires = space.luminaires
      space_space_type = space.spaceType
      if not space_space_type.empty?
        space_space_type_lights = space_space_type.get.lights
      else
        space_space_type_lights = []
      end

      thermal_zone = space.thermalZone
      if(thermal_zone)
        multiplier = thermal_zone.get.multiplier
      else
        multiplier = 1
      end
      affected_area = affected_area + space.floorArea * multiplier

      # array to manage light schedules within a space
      space_lights_array = []

      #if space has lights and space type also has lights
      if space_lights.size > 0 and space_space_type_lights.size > 0

        #loop through and remove all lights and luminaires
        space_lights.each do |space_light|
          space_light.remove
        end
        runner.registerWarning("The space named '#{space.name.to_s}' had one or more light objects. These were deleted and a new LPD light object was added to the parent space type named '#{space_space_type.get.name.to_s}'.")

        space_luminaires.each do |space_luminaire|
          space_luminaire.remove
        end
        if space_luminaires.size > 0
          runner.registerWarning("Luminaire objects have been removed. Their schedules were not taken into consideration when choosing schedules for the new LPD light object.")
        end

      elsif space_lights.size > 0 and space_space_type_lights.size == 0

        #inspect schedules for light objects
        multiple_schedules = false
        lights_schedules = []
        space_lights.each do |space_light|
        lights_data_for_array = []
          if not space_light.schedule.empty?
            space_light_new_schedule =  space_light.schedule
            if not space_light_new_schedule.empty?
              lights_schedules << space_light_new_schedule.get
              if not space_light.powerPerFloorArea.empty?
                lights_data_for_array << space_light.powerPerFloorArea.get
              else
                lights_data_for_array << 0.0
              end
              lights_data_for_array << space_light_new_schedule.get
              lights_data_for_array << space_light.isScheduleDefaulted
              space_lights_array << lights_data_for_array
            end
          end
        end

        # pick schedule to use and see if it is defaulted
        space_lights_array = space_lights_array.sort.reverse[0]
        if not space_lights_array == nil
          if not space_lights_array[2] == true
            preferred_schedule = space_lights_array[1]
          else
            #leave schedule blank, it is defaulted
          end
        end

        #flag if lights_schedules has more than one unique object
        if lights_schedules.uniq.size > 1
          multiple_schedules = true
        end

        #delete lights and luminaires and add in new light.
        space_lights.each do |space_light|
          space_light.remove
        end
        space_luminaires.each do |space_luminaire|
          space_luminaire.remove
        end
        space_light_new = template_light_inst.clone(model)
        space_light_new = space_light_new.to_Lights.get
        space_light_new.setSpace(space)

        #only add component cost line item objects if the user entered some non 0 cost values
        if cost_included

          # creating componentCostLineItem
          ccli = OpenStudio::Model::ComponentCostLineItem.new(space_light_new)
          ccli.setMaterialCost(proposed_material_cost_si.value - baseline_material_cost_si.value)
          ccli.setMaterialCost(proposed_installation_cost_si.value - baseline_installation_cost_si.value)
          ccli.setDemolitionCost(proposed_demolition_cost_si.value - baseline_demolition_cost_si.value)
          ccli.setSalvageValue(proposed_salvage_value_si.value - baseline_salvage_value_si.value)
          crc = ccli.addComponentRecurringCost("ComponentRecurringCost","Maintenance",proposed_recurring_cost.get - baseline_recurring_cost.get,units)
          ccli.setExpectedLife(expected_life)

          ccli.setMaterialCostUnits(units)
          ccli.setInstallationCostUnits(units)
          ccli.setDemolitionCostUnits(units)
          ccli.setSalvageValueUnits(units)

          capital_cost_per_area = capital_cost_per_area + ccli.materialCost.get
          capital_cost_per_area = capital_cost_per_area + ccli.installationCost.get

          if(retrofit == "Retrofit")
            # creating second componentCostLineItem with infinite life
            retrofit_ccli = OpenStudio::Model::ComponentCostLineItem.new(space_type_light_new)
            retrofit_ccli.setMaterialCost(baseline_material_cost_si.value - baseline_salvage_value_si.value)
            retrofit_ccli.setInstallationCost(baseline_installation_cost_si.value + baseline_demolition_cost_si.value)
            retrofit_ccli.setMaterialCostUnits(units)
            retrofit_ccli.setInstallationCostUnits(units)

            capital_cost_per_area = capital_cost_per_area + ccli.materialCost.get
            capital_cost_per_area = capital_cost_per_area + ccli.installationCost.get
          end

        end

        #assign preferred schedule to new lights object
        if not space_light_new.schedule.nil? and not space_lights_array[2] == true
          space_light_new.setSchedule(preferred_schedule)
        else
          runner.registerWarning("No schedule is associated with the new lights object in space #{space.name}.")          
        end

        #if schedules had to be removed due to multiple lights add warning here
        if not space_light_new.schedule.nil? and multiple_schedules == true
          space_light_new_schedule = space_light_new.schedule
          runner.registerWarning("The space type named '#{space.name.to_s}' had more than one light object with unique schedules. The schedule named '#{space_light_new_schedule.get.name.to_s}' was used for the new LPD light object.")
        end

      elsif space_lights.size == 0 and space_space_type_lights.size == 0
        #issue warning that the space does not have any direct or inherited lights.
        runner.registerInfo("The space named '#{space.name.to_s}' does not have any direct or inherited lights.")

      end #end of if space and space type have lights

    end #end of loop through spaces

    #clean up template light instance. Will EnergyPlus will fail if you have an instance that isn't associated with a space or space type
    template_light_inst.remove

    #ip area for reporting
    const_area_si = OpenStudio::Quantity.new(affected_area, unit_area_si)
    const_area_ip = OpenStudio::convert(const_area_si, unit_area_ip).get

    #calculate capital cost for new and retrofit workflow to use in final condition
    capital_cost_per_area_si = OpenStudio::Quantity.new(capital_cost_per_area, unit_cost_per_area_si)
    capital_cost_per_area_ip = OpenStudio::convert(capital_cost_per_area_si, unit_cost_per_area_ip).get

    #report final condition
    building_final_lpd_si = OpenStudio::Quantity.new(building.lightingPowerPerFloorArea, unit_lpd_si)
    building_final_lpd_ip = OpenStudio::convert(building_final_lpd_si, unit_lpd_ip).get
    #runner.registerFinalCondition("Your model's final LPD is #{building_final_lpd_ip}.")
    #Final Condition: LPD was set to $NEW_LPD$ in $AREA_AFFECTED$ ft^2 of the building, at a cost of $COST_PER_AREA$.  The building now has an overall average LPD of $FINAL_LPD$ W/ft^2.
    runner.registerFinalCondition("LPD was set to #{pretty_numbers(lpd)} in #{pretty_numbers(const_area_ip.value)} ft^2 of the building, at a cost of #{pretty_numbers(capital_cost_per_area_ip.value)}.  The building now has an overall average LPD of #{pretty_numbers(building_final_lpd_si.value)} W/ft^2")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
SetLightingLoadsByLPD.new.registerWithApplication