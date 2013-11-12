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

    #make an argument for material and installation cost
    material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("material_cost",true)
    material_cost.setDisplayName("Material and Installation Costs per Space for Daylight Sensor ($).")
    material_cost.setDefaultValue(0.0)
    args << material_cost

    #make an argument for demolition cost
    demolition_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("demolition_cost",true)
    demolition_cost.setDisplayName("Demolition Costs per Space for Daylight Sensor ($).")
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
    om_cost.setDisplayName("O & M Costs per Space for Daylight Sensor ($).")
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
    space_type = runner.getOptionalWorkspaceObjectChoiceValue("space_type",user_arguments,model)
    setpoint = runner.getDoubleArgumentValue("setpoint",user_arguments)
    control_type = runner.getStringArgumentValue("control_type",user_arguments)
    min_power_fraction = runner.getDoubleArgumentValue("min_power_fraction",user_arguments)
    min_light_fraction = runner.getDoubleArgumentValue("min_light_fraction",user_arguments)
    height = runner.getDoubleArgumentValue("height",user_arguments)
    material_cost = runner.getDoubleArgumentValue("material_cost",user_arguments)
    demolition_cost = runner.getDoubleArgumentValue("demolition_cost",user_arguments)
    years_until_costs_start = runner.getIntegerArgumentValue("years_until_costs_start",user_arguments)
    demo_cost_initial_const = runner.getBoolArgumentValue("demo_cost_initial_const",user_arguments)
    expected_life = runner.getIntegerArgumentValue("expected_life",user_arguments)
    om_cost = runner.getDoubleArgumentValue("om_cost",user_arguments)
    om_frequency = runner.getIntegerArgumentValue("om_frequency",user_arguments)

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

    #set flags to use later
    costs_requested = false
    warning_cost_assign_to_space = false

    #check costs for reasonableness
    if material_cost.abs + demolition_cost.abs + om_cost.abs == 0
      runner.registerInfo("No costs were requested for Exterior Lights.")
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

    #setup OpenStudio units that we will need
    unit_setpoint_ip = OpenStudio::createUnit("fc").get
    unit_setpoint_si = OpenStudio::createUnit("lux").get
    unit_height_ip = OpenStudio::createUnit("ft").get
    unit_height_si = OpenStudio::createUnit("m").get

    #define starting units
    setpoint_ip = OpenStudio::Quantity.new(setpoint, unit_setpoint_ip)
    height_ip = OpenStudio::Quantity.new(height/12, unit_height_ip)

    #unit conversion from IP units to SI units
    setpoint_si = OpenStudio::convert(setpoint_ip, unit_setpoint_si).get
    height_si = OpenStudio::convert(height_ip, unit_height_si).get

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
    runner.registerInitialCondition("#{spaces_using_space_type.size} spaces are assigned to space type '#{space_type.name}'.")

    #get starting costs for spaces
    yr0_capital_totalCosts = -1*get_total_costs_for_objects(spaces_using_space_type)

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
        runner.registerWarning("Space '#{space_using_space_type.name}' already has a daylighting sensor. No sensor was added.")
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

      #add lifeCycleCost objects if there is a non-zero value in one of the cost arguments
      if costs_requested == true

        starting_lcc_counter = space.lifeCycleCosts.size

        #adding new cost items
        lcc_mat = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Mat - #{sensor.name}", space, material_cost, "CostPerEach", "Construction", expected_life, years_until_costs_start)
        if demo_cost_initial_const
          lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{sensor.name}", space, demolition_cost, "CostPerEach", "Salvage", expected_life, years_until_costs_start)
        else
          lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{sensor.name}", space, demolition_cost, "CostPerEach", "Salvage", expected_life, years_until_costs_start+expected_life)
        end
        lcc_om = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_OM - #{sensor.name}", space, om_cost, "CostPerEach", "Maintenance", om_frequency, 0)

        if space.lifeCycleCosts.size - starting_lcc_counter == 3
          if not warning_cost_assign_to_space
            runner.registerInfo("Cost for daylight sensors was added to spaces. The cost will remain in the model unless the space is removed. Removing only the sensor will nto remove the cost.")
            warning_cost_assign_to_space = true
          end
        else
          runner.registerWarning("The measure did not function as expected. #{space.lifeCycleCosts.size - starting_lcc_counter} LifeCycleCost objects were made, 3 were expected.")
        end

      end #end of costs_requested == true

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

    if sensor_count == 0 and costs_requested == false
      runner.registerAsNotApplicable("No spaces that currently don't have sensor required a new sensor, and not lifecycle costs were requested.")
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

    #get final costs for spaces
    yr0_capital_totalCosts = get_total_costs_for_objects(spaces_using_space_type)

    #reporting final condition of model
    runner.registerFinalCondition("Added daylighting controls to #{sensor_count} spaces, covering #{area_ip}. Initial year costs associated with the daylighting controls is $#{neat_numbers(yr0_capital_totalCosts,0)}.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AddDaylightSensors.new.registerWithApplication