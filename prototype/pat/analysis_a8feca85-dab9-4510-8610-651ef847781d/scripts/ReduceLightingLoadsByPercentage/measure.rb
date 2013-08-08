#start the measure
class ReduceLightingLoadsByPercentage < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Reduce Building Lighting by Percentage"
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

    #make a choice argument for space type
    space_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("space_type", space_type_handles, space_type_display_names)
    space_type.setDisplayName("Apply the Measure to a Specific Space Type or to the Entire Model")
    space_type.setDefaultValue("*Entire Building*") #if no space type is chosen this will run on the entire building
    args << space_type

    #make an argument for reduction percentage
    reduction_percent = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("reduction_percent",true)
    reduction_percent.setDisplayName("Electric Equipment Power Reduction Percentage")
    reduction_percent.setDefaultValue(30.0)
    args << reduction_percent

    #make an argument for material and installation cost
    material_and_installation_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("material_and_installation_cost",true)
    material_and_installation_cost.setDisplayName("Increase in Material and Installation Cost for Lighting per Floor Area (%).")
    material_and_installation_cost.setDefaultValue(150.0)
    args << material_and_installation_cost

    #make an argument for demolition cost
    demolition_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("demolition_cost",true)
    demolition_cost.setDisplayName("Increase in Demolition Costs for Lighting per Floor Area (%).")
    demolition_cost.setDefaultValue(0.0)
    args << demolition_cost

    #make an argument for years until costs start
    years_until_costs_start = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("years_until_costs_start",true)
    years_until_costs_start.setDisplayName("Years Until Costs Start (whole years).")
    years_until_costs_start.setDefaultValue(0)
    args << years_until_costs_start

    #make a choice argument for when demo costs occur
    initial_demo_costs = OpenStudio::Ruleset::OSArgument::makeBoolArgument("initial_demo_costs",true)
    initial_demo_costs.setDisplayName("Demolition Costs Occur During Initial Construction?")
    initial_demo_costs.setDefaultValue(false)
    args << initial_demo_costs

    #make an argument for expected life
    expected_life = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("expected_life",true)
    expected_life.setDisplayName("Expected Life (whole years)")
    expected_life.setDefaultValue(15)
    args << expected_life

    #make an argument for O & M cost
    om_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("om_cost",true)
    om_cost.setDisplayName("Increase O & M Costs for Lighting per Floor Area (%).")
    om_cost.setDefaultValue(0.0)
    args << om_cost

    #make an argument for O & M frequency
    om_frequency = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("om_frequency",true)
    om_frequency.setDisplayName("O & M Frequency (whole years).")
    om_frequency.setDefaultValue(1)
    args << om_frequency

    return args
  end #end the arguments method
  
  def getLights(reduction_percent,
              material_and_installation_cost,
              demolition_cost,
              om_cost,
              total_costs,
              area_affected,
              runner,
              model,
              cloned_defs,
              modelObjects,
              areLights)
          
    modelObjects.each do |modelObject|

      #clone def if it has not already been cloned
      if(areLights)
        exist_def = modelObject.lightsDefinition
      else
        exist_def = modelObject.luminaireDefinition
      end
      if cloned_defs.any? {|k,v| k.include?(exist_def.name.to_s)}
        new_def = cloned_defs[exist_def.name.to_s]
      else
        new_def = exist_def.clone(model)
        if(areLights)
          new_def = new_def.to_LightsDefinition.get
        else
          new_def = new_def.to_LuminaireDefinition.get
        end
        new_def_name = new_def.setName("#{exist_def.name.to_s} - #{reduction_percent} percent reduction")

        #add to the hash
        cloned_defs[exist_def.name.to_s] = new_def

       #edit clone based on percentage reduction
        if(areLights)
          if not new_def.lightingLevel.empty?
            new_lighting_level = new_def.setLightingLevel(new_def.lightingLevel.get - new_def.lightingLevel.get*reduction_percent*0.01)
          elsif not new_def.wattsperSpaceFloorArea.empty?
            new_lighting_per_area = new_def.setWattsperSpaceFloorArea(new_def.wattsperSpaceFloorArea.get - new_def.wattsperSpaceFloorArea.get*reduction_percent*0.01)
          elsif not new_def.wattsperPerson.empty?
            new_lighting_per_person = new_def.setWattsperPerson(new_def.wattsperPerson.get - new_def.wattsperPerson.get*reduction_percent*0.01)
          else
            runner.registerWarning("The lights definition named '#{modelObject.lightsDefinition.name}' is used by one or more light objects and has no load values. It was not altered.")
          end
        else
          if new_def.lightingPower > 0
            new_lighting_level = new_def.setLightingPower(new_def.lightingPower - new_def.lightingPower*reduction_percent*0.01)
          else
            runner.registerWarning("The luminaire definition named '#{modelObject.lightsDefinition.name}' is used by one or more luminaire instance objects and has no load values. It was not altered.")
          end
        end
        
        my_lifeCycleCosts = new_def.lifeCycleCosts
        my_lifeCycleCosts.each do |my_lifeCycleCost|
          if my_lifeCycleCost.category == "Construction"
            my_lifeCycleCost.setCost(my_lifeCycleCost.cost * (1 + material_and_installation_cost/100))
            total_cost += my_lifeCycleCost.cost
          elsif my_lifeCycleCost.category == "Salvage"
            my_lifeCycleCost.setCost(my_lifeCycleCost.cost * (1 + demolition_cost/100))
          elsif my_lifeCycleCost.category == "Maintenance"
            my_lifeCycleCost.setCost(my_lifeCycleCost.cost * (1 + om_cost/100))
          end
        end

        area_affected += new_def.floorArea
        
      end #end cloned_defs.any?

      #link instance with clone and rename
      updated_instance = modelObject.setLightsDefinition(new_def)
      updated_instance_name = modelObject.setName("#{modelObject.name} - #{reduction_percent} percent reduction")

    end #end space_type_luminaires.each do
  
  end  #end def

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    object = runner.getOptionalWorkspaceObjectChoiceValue("space_type",user_arguments,model)
    reduction_percent = runner.getDoubleArgumentValue("reduction_percent",user_arguments)
    material_and_installation_cost = runner.getDoubleArgumentValue("material_and_installation_cost",user_arguments)
    demolition_cost = runner.getDoubleArgumentValue("demolition_cost",user_arguments)
    years_until_costs_start = runner.getIntegerArgumentValue("years_until_costs_start",user_arguments)
    initial_demo_costs = runner.getBoolArgumentValue("initial_demo_costs",user_arguments)
    expected_life = runner.getIntegerArgumentValue("expected_life",user_arguments)
    om_cost = runner.getDoubleArgumentValue("om_cost",user_arguments)
    om_frequency = runner.getIntegerArgumentValue("om_frequency",user_arguments)

    #check the space_type for reasonableness and see if measure should run on space type or on the entire building
    apply_to_building = false
    space_type = nil
    if object.empty?
      handle = runner.getStringArgumentValue("space_type",user_arguments)
      if handle.empty?
        runner.registerError("No space type was chosen.")
      else
        runner.registerError("The selected space type with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not object.get.to_SpaceType.empty?
        space_type = object.get.to_SpaceType.get
      elsif not object.get.to_Building.empty?
        apply_to_building = true
      else
        runner.registerError("Script Error - argument not showing up as space type or building.")
        return false
      end
    end

    #check the reduction_percent for reasonableness
    if reduction_percent > 100
      runner.registerError("Please enter a value less than or equal to 100 for the lighting power reduction percentage.")
      return false
    elsif reduction_percent == 0
      runner.registerAsNotApplicable("No lighting power adjustment requested, nothing will be changed.")
    elsif reduction_percent < 1 and reduction_percent > -1
      runner.registerWarning("An electric power reduction percentage of #{reduction_percent} is abnormally low.")
    elsif reduction_percent > 90
      runner.registerWarning("An electric power reduction percentage of #{reduction_percent} is abnormally high.")
    elsif reduction_percent < 0
      runner.registerWarning("The requested value for lighting power reduction percentage was negative. This will result in an increase in lighting power.")
    end

    if material_and_installation_cost < 0
      runner.registerError("Leave Material and Installation Cost blank or enter a non-negative number.")
      return false
    end

    if demolition_cost < 0
      runner.registerError("Leave Demolition Cost blank or enter a non-negative number.")
      return false
    end

    if years_until_costs_start < 0
      runner.registerError("Enter an integer greater than or equal to 0 for Years Until Costs Start.")
      return false
    end

    if expected_life < 1
      runner.registerError("Enter an integer greater than or equal to 1 for Expected Life.")
      return false
    end

    if om_cost < 0
      runner.registerError("Leave O & M Cost blank or enter a non-negative number.")
      return false
    end

    if om_frequency < 1
      runner.registerError("Choose an integer greater than 0 for O & M Frequency.")
    end

    unit_area_ip = OpenStudio::createUnit("ft^2").get
    unit_area_si = OpenStudio::createUnit("m^2").get

    #report initial condition
    building = model.getBuilding
    building_area_si = OpenStudio::Quantity.new(building.floorArea, unit_area_si)
    building_area_ip = OpenStudio::convert(building_area_si, unit_area_ip).get
    initial_building_lighting_power = building.lightingPower
    lpd = initial_building_lighting_power / building_area_ip.value

    runner.registerInitialCondition("The model's initial building lighting power was #{initial_building_lighting_power.round} W, a power density of #{pretty_numbers(lpd)} W/ft^2.")

    #make a hash of old defs and new lights and luminaire defs
    cloned_lights_defs = {}
    cloned_luminaire_defs = {}

    total_costs = 0
    area_affected = 0
    
    #get space types in model
    if apply_to_building
      space_types = model.getSpaceTypes
    else
      space_types = []
      space_types << space_type #only run on a single space type
    end

    space_types.each do |space_type|
      space_type_lights = space_type.lights
      getLights(reduction_percent,
                material_and_installation_cost,
                demolition_cost,
                om_cost,
                total_costs,
                area_affected,
                runner,
                model,
                cloned_lights_defs,
                space_type_lights,
                true)

      space_type_luminaires = space_type.luminaires
      getLights(reduction_percent,
                material_and_installation_cost,
                demolition_cost,
                om_cost,
                total_costs,
                area_affected,
                runner,
                model,
                cloned_luminaire_defs,
                space_type_luminaires,
                false)
    end

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
      getLights(reduction_percent,
                material_and_installation_cost,
                demolition_cost,
                om_cost,
                total_costs,
                area_affected,
                runner,
                model,
                cloned_lights_defs,
                space_lights,
                true)
      space_luminaires = space.luminaires
      getLights(reduction_percent,
                material_and_installation_cost,
                demolition_cost,
                om_cost,
                total_costs,
                area_affected,
                runner,
                model,
                cloned_luminaire_defs,
                space_luminaires,
                false)      
    end
    
    if (cloned_lights_defs.size == 0 and cloned_luminaire_defs.size == 0)
      runner.registerAsNotApplicable("No lighting or luminaire objects were found in the specified space type(s).")
    end

    #report final condition
    final_building = model.getBuilding
    final_building_lighting_power = final_building.lightingPower
    lpd = final_building_lighting_power / building_area_ip.value
    runner.registerFinalCondition("LPD was reduced by #{pretty_numbers(reduction_percent)}% in selected spaces.  The building now has an overall average of #{pretty_numbers(lpd)} W/ft^2.")
    
    return true

  end #end the run method

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
    
end #end the measure

#this allows the measure to be used by the application
ReduceLightingLoadsByPercentage.new.registerWithApplication