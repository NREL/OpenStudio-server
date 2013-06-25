#start the measure
class AddDaylightSensors < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Add Daylight Sensor at the Center of Spaces with a Specified Space Type Assigned"
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

    #make a choice argument for space type
    space_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("space_type", space_type_handles, space_type_display_names,true)
    space_type.setDisplayName("Add Daylight Sensors to Spaces of This Space Type")
    space_type.setDefaultValue("*Entire Building*")
    args << space_type

    #make an argument for setpoint
    setpoint = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("setpoint",true)
    setpoint.setDisplayName("Daylighting Setpoint (fc)")
    setpoint.setDefaultValue(45.0)
    args << setpoint

    #make an argument for control_type
    chs = OpenStudio::StringVector.new
    chs << "None"
    chs << "Continuous"
    chs << "Stepped"
    chs << "Continuous/Off"
    control_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("control_type",chs)
    control_type.setDisplayName("Daylighting Control Type")
    control_type.setDefaultValue("Continuous/Off")
    args << control_type

    #make an argument for min_power_fraction
    min_power_fraction = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_power_fraction",true)
    min_power_fraction.setDisplayName("Daylighting Minimum Input Power Fraction(min = 0 max = 0.6)")
    min_power_fraction.setDefaultValue(0.3)
    args << min_power_fraction

    #make an argument for min_light_fraction
    min_light_fraction = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_light_fraction",true)
    min_light_fraction.setDisplayName("Daylighting Minimum Light Output Fraction (min = 0 max = 0.6)")
    min_light_fraction.setDefaultValue(0.2)
    args << min_light_fraction

    #make an argument for height
    height = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("height",true)
    height.setDisplayName("Sensor Height (inches)")
    height.setDefaultValue(30.0)
    args << height

    #make a choice argument for units
    units_display_names = OpenStudio::StringVector.new
    units_display_names << "CostPerEach"
    units = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("units", units_display_names)
    units.setDefaultValue("CostPerEach")
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
    space_type = runner.getOptionalWorkspaceObjectChoiceValue("space_type",user_arguments,model)
    setpoint = runner.getDoubleArgumentValue("setpoint",user_arguments)
    control_type = runner.getStringArgumentValue("control_type",user_arguments)
    min_power_fraction = runner.getDoubleArgumentValue("min_power_fraction",user_arguments)
    min_light_fraction = runner.getDoubleArgumentValue("min_light_fraction",user_arguments)
    height = runner.getDoubleArgumentValue("height",user_arguments)
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
    unit_setpoint_ip = OpenStudio::createUnit("fc").get
    unit_setpoint_si = OpenStudio::createUnit("lux").get
    unit_height_ip = OpenStudio::createUnit("ft").get
    unit_height_si = OpenStudio::createUnit("m").get
    unit_cost_per_area_ip = OpenStudio::createUnit("1/ft^2").get #$/ft^2 does not work
    unit_cost_per_area_si = OpenStudio::createUnit("1/m^2").get
    unit_area_ip = OpenStudio::createUnit("ft^2").get
    unit_area_si = OpenStudio::createUnit("m^2").get

    #define starting units
    setpoint_ip = OpenStudio::Quantity.new(setpoint, unit_setpoint_ip)
    height_ip = OpenStudio::Quantity.new(height/12, unit_height_ip)

    #unit conversion from IP units to SI units
    setpoint_si = OpenStudio::convert(setpoint_ip, unit_setpoint_si).get
    height_si = OpenStudio::convert(height_ip, unit_height_si).get

    #check the space_type for reasonableness
    if space_type.empty?
      handle = runner.getStringArgumentValue("space_type",user_arguments)
      if handle.empty?
        runner.registerError("No SpaceType was chosen.")
      else
        runner.registerError("The selected space type with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not space_type.get.to_SpaceType.empty?
        space_type = space_type.get.to_SpaceType.get
      else
        runner.registerError("Script Error - argument not showing up as space type.")
        return false
      end
    end

    #check the setpoint for reasonableness
    if setpoint < 0 or setpoint > 9999 #dfg need input on good value
      runner.registerError("A setpoint of #{setpoint} foot-candles is outside the measure limit.")
      return false
    elsif setpoint > 999
      runner.registerWarning("A setpoint of #{setpoint} foot-candles is abnormally high.") #dfg need input on good value
    end

    #check the min_power_fraction for reasonableness
    if min_power_fraction < 0.0 or min_power_fraction > 0.6
      runner.registerError("The requested minimum input power fraction of #{min_power_fraction} for continuous dimming control is outside the acceptable range of 0 to 0.6.")
      return false
    end

    #check the min_light_fraction for reasonableness
    if min_light_fraction < 0.0 or min_light_fraction > 0.6
      runner.registerError("The requested minimum light output fraction of #{min_light_fraction} for continuous dimming control is outside the acceptable range of 0 to 0.6.")
      return false
    end

    #check the height for reasonableness
    if height < -360 or height > 360 # neg ok because space origin may not be floor
      runner.registerError("A setpoint of #{height} inches is outside the measure limit.")
      return false
    elsif height > 72
      runner.registerWarning("A setpoint of #{height} inches is abnormally high.")
    elseif height < 0
      runner.registerWarning("Typically the sensor height should be a positive number, however if your space origin is above the floor then a negative sensor height may be approriate.")
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

    #variable to tally the area to which the overall measure is applied
    area = 0
    #variables to aggregate the number of sensors installed and the area affected
    sensor_count = 0
    sensor_area = 0
    spaces_using_space_type = space_type.spaces
    #array with subset of spaces
    spaces_using_space_type_in_zones_without_sensors = []
    affected_zones = []
    affected_zone_names = []
    #hash to hold sensor objects
    new_sensor_objects = {}

    #reporting initial condition of model
    starting_spaces = model.getSpaces
    #runner.registerInitialCondition("#{spaces_using_space_type.size} spaces are assigned to space type '#{space_type.name}'.")
    #Initial Condition: The building has $INITIAL_NUM_SPCS_W_DAYLIGHT_CTRLS$ spaces with daylight sensors.
    runner.registerInitialCondition("The building has #{spaces_using_space_type.size} spaces with daylight sensors.")

    capital_cost_per_each = 0

    #test that there is no sensor already in the space, and that zone object doesn't already have sensors assigned.
    spaces_using_space_type.each do |space_using_space_type|
      if space_using_space_type.daylightingControls.length == 0
        space_zone = space_using_space_type.thermalZone
        if not space_zone.empty?
          space_zone = space_zone.get
          if space_zone.primaryDaylightingControl.empty? and space_zone.secondaryDaylightingControl.empty?
            spaces_using_space_type_in_zones_without_sensors << space_using_space_type
          elsif
            runner.registerWarning("Thermal zone '#{space_zone.name}' which includes space '#{space_using_space_type.name}' already had a daylighting sensor. No sensor was added to space '#{space_using_space_type.name}'.")
          end
        else
          runner.registerWarning("Space '#{space_using_space_type.name}' is not associated with a thermal zone. It won't be part of the EnergyPlus simulation.")
        end
      else
        runner.registerWarning("Space '#{space_using_space_type.name}' alredy has a daylighting sensor. No sensor was added.")
      end
    end

    #loop through all spaces,
    #and add a daylighting sensor with dimming to each
    space_count = 0
    spaces_using_space_type_in_zones_without_sensors.each do |space|
      space_count = space_count + 1
      area += space.floorArea

      #eliminate spaces that don't have exterior natural lighting
      has_ext_nat_light = false
      space.surfaces.each do |surface|
        next if not surface.outsideBoundaryCondition == "Outdoors"
        surface.subSurfaces.each do |sub_surface|
          next if sub_surface.subSurfaceType == "Door"
          next if sub_surface.subSurfaceType == "OverheadDoor"
          has_ext_nat_light = true
        end
      end
      if has_ext_nat_light == false
        runner.registerWarning("Space '#{space.name}' has no exterior natural lighting. No sensor will be added.")
       next
      end

      #find floors
      floors = []
      space.surfaces.each do |surface|
        next if not surface.surfaceType == "Floor"
        floors << surface
      end

      #this method only works for flat (non-inclined) floors
      boundingBox = OpenStudio::BoundingBox.new
      floors.each do |floor|
        boundingBox.addPoints(floor.vertices)
      end
      xmin = boundingBox.minX.get
      ymin = boundingBox.minY.get
      zmin = boundingBox.minZ.get
      xmax = boundingBox.maxX.get
      ymax = boundingBox.maxY.get

      #create a new sensor and put at the center of the space
      sensor = OpenStudio::Model::DaylightingControl.new(model)
      sensor.setName("#{space.name} daylighting control")
      x_pos = (xmin + xmax) / 2
      y_pos = (ymin + ymax) / 2
      z_pos = zmin + height_si.value #put it 1 meter above the floor
      new_point = OpenStudio::Point3d.new(x_pos, y_pos, z_pos)
      sensor.setPosition(new_point)
      sensor.setIlluminanceSetpoint(setpoint)
      sensor.setLightingControlType(control_type)
      sensor.setMinimumInputPowerFractionforContinuousDimmingControl(min_power_fraction)
      sensor.setMinimumLightOutputFractionforContinuousDimmingControl(min_light_fraction)
      sensor.setSpace(space)

      #only add component cost line item objects if the user entered some non 0 cost values
      if cost_included

        # creating componentCostLineItem
        ccli = OpenStudio::Model::ComponentCostLineItem.new(sensor)
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

        capital_cost_per_each = capital_cost_per_each + ccli.materialCost.get
        capital_cost_per_each = capital_cost_per_each + ccli.installationCost.get

        if(retrofit == "Retrofit")
          # creating second componentCostLineItem with infinite life
          retrofit_ccli = OpenStudio::Model::ComponentCostLineItem.new(sensor)
          retrofit_ccli.setMaterialCost(baseline_material_cost_si.value - baseline_salvage_value_si.value)
          retrofit_ccli.setInstallationCost(baseline_installation_cost_si.value + baseline_demolition_cost_si.value)
          retrofit_ccli.setMaterialCostUnits(units)
          retrofit_ccli.setInstallationCostUnits(units)

          capital_cost_per_each = capital_cost_per_each + retrofit_ccli.materialCost.get
          capital_cost_per_each = capital_cost_per_each + retrofit_ccli.installationCost.get

        end

      end

      #push unique zones to array for use later in measure
      temp_zone = space.thermalZone.get
      if affected_zone_names.include?(temp_zone.name.to_s) == false
        affected_zones << temp_zone
        affected_zone_names << temp_zone.name.to_s
      end

      #push sensor object into hash with space name
      new_sensor_objects[space.name.to_s] = sensor

      #add floor area to the daylighting area tally
      sensor_area += space.floorArea

      #add to sensor count for reporting
      sensor_count += 1

    end #end spaces_using_space_type_without_sensors.each do

    if sensor_count == 0
      runner.registerAsNotApplicable("No spaces that currently don't have sensor required a new sensor.")
      return true
    end

    #loop through thermal Zones for spaces with daylighting controls added
    affected_zones.each do |zone|
      zone_spaces = zone.spaces
      zone_spaces_with_new_sensors = []
      zone_spaces.each do |zone_space|
        if not zone_space.daylightingControls.empty? and zone_space.spaceType.get == space_type
          zone_spaces_with_new_sensors << zone_space
        end
      end

      if not zone_spaces_with_new_sensors.empty?
        #need to identify the two largest spaces
        primary_area = 0
        secondary_area = 0
        primary_space = nil
        secondary_space = nil
        three_or_more_sensors = false

        # dfg temp - need to add another if statement so only get spaces with sensors
        zone_spaces_with_new_sensors.each do |zone_space|
          zone_space_area = zone_space.floorArea
          if zone_space_area > primary_area
            primary_area = zone_space_area
            primary_space = zone_space
          elsif zone_space_area > secondary_area
            secondary_area = zone_space_area
            secondary_space = zone_space
          else
            #setup flag to warn user that more than 2 sensors can't be added to a space
            three_or_more_sensors = true
          end

        end

        if primary_space
          #setup primary sensor
          sensor_primary = new_sensor_objects[primary_space.name.to_s]
          zone.setPrimaryDaylightingControl(sensor_primary)
          zone.setFractionofZoneControlledbyPrimaryDaylightingControl(primary_area/(primary_area + secondary_area))
        end

        if secondary_space
          #setup secondary sensor
          sensor_secondary = new_sensor_objects[secondary_space.name.to_s]
          zone.setSecondaryDaylightingControl(sensor_secondary)
          zone.setFractionofZoneControlledbySecondaryDaylightingControl(secondary_area/(primary_area + secondary_area))
          runner.registerInfo("Connecting new daylight sensors with thermal zone '#{zone.name}'.")
        end

        #warn that additional sensors were not used
        if three_or_more_sensors == true
          runner.registerWarning("Thermal zone '#{zone.name}' had more than two spaces with sensors. Only two sensors were associated with the thermal zone.")
        end

      end #end if not zone_spaces.empty?

    end #end affected_zones.each do

    #setup OpenStudio units that we will need
    unit_area_ip = OpenStudio::createUnit("ft^2").get
    unit_area_si = OpenStudio::createUnit("m^2").get

    #define starting units
    area_si = OpenStudio::Quantity.new(sensor_area, unit_area_si)

    #unit conversion from IP units to SI units
    area_ip = OpenStudio::convert(area_si, unit_area_ip).get

    #reporting final condition of model
    finishing_spaces = model.getSpaces
    #runner.registerFinalCondition("Added daylighting controls to #{sensor_count} spaces, covering #{area_ip}.")
    #Final Condition: Daylight sensors were installed in $NUM_SPCS_NEW_DAYLIGHT_CTRL$ spaces at a cost of $COST_PER$.  The building now has $INITIAL_NUM_SPCS_W_DAYLIGHT_CTRLS$ spaces with daylight sensors.
    total_sensor_count = spaces_using_space_type.size + sensor_count
    runner.registerFinalCondition("Daylight sensors were installed in #{sensor_count} spaces at a cost of #{capital_cost_per_each}.  The building now has #{total_sensor_count} spaces with daylight sensors.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AddDaylightSensors.new.registerWithApplication