
class SetWindowToWallRatioByFacade < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Set Window to Wall Ratio by Facade"
  end

  # return a vector of arguments
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make double argument for wwr
    wwr = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("wwr",true)
    wwr.setDisplayName("Window to Wall Ratio (fraction)")
    wwr.setDefaultValue(0.4)
    args << wwr

    #make double argument for sillHeight
    sillHeight = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sillHeight",true)
    sillHeight.setDisplayName("Sill Height (in)")
    sillHeight.setDefaultValue(30.0)
    args << sillHeight

    #make choice argument for facade
    choices = OpenStudio::StringVector.new
    choices << "North"
    choices << "East"
    choices << "South"
    choices << "West"
    facade = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("facade", choices,true)
    facade.setDisplayName("Cardinal Direction")
    facade.setDefaultValue("South")
    args << facade
    
    #make an optional argument for proposed material cost
    proposed_material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_material_cost",false)
    proposed_material_cost.setDisplayName("Material Cost for Increase in Window vs. Wall Area ($/ft^2)")
    args << proposed_material_cost
    
    #make an optional argument for proposed installation cost
    proposed_installation_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_installation_cost",false)
    proposed_installation_cost.setDisplayName("Installation Cost for Increase in Window vs. Wall Area ($/ft^2)")
    args << proposed_installation_cost

    #make an optional argument for proposed recurring cost
    proposed_recurring_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_recurring_cost",false)
    proposed_recurring_cost.setDisplayName("Recurring Cost for Increase in Window vs. Wall Area ($/ft^2)")
    args << proposed_recurring_cost    
    
    #make an optional argument for expected life (single value for both baseline and proposed)
    #limit to integer vs. double
    expected_life = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("expected_life",false)
    expected_life.setDisplayName("Expected Life - Single Value for Baseline and Proposed (whole years)")
    expected_life.setDefaultValue(20)
    args << expected_life    

    return args
  end  #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model),user_arguments)
      return false
    end

    #assign the user inputs to variables
    wwr = runner.getDoubleArgumentValue("wwr",user_arguments)
    sillHeight = runner.getDoubleArgumentValue("sillHeight",user_arguments)
    facade = runner.getStringArgumentValue("facade",user_arguments)
    proposed_material_cost = runner.getOptionalDoubleArgumentValue("proposed_material_cost",user_arguments)
    proposed_installation_cost = runner.getOptionalDoubleArgumentValue("proposed_installation_cost",user_arguments)
    proposed_recurring_cost = runner.getOptionalDoubleArgumentValue("proposed_recurring_cost",user_arguments)
    expected_life = runner.getOptionalIntegerArgumentValue("expected_life",user_arguments)

    #check reasonableness of fraction
    if wwr <= 0 or wwr >= 1
      runner.registerError("Window to Wall Ratio must be greater than 0 and less than 1.")
      return false
    end

    #check reasonableness of fraction
    if sillHeight <= 0
      runner.registerError("Sill height must be > 0.")
      return false
    elsif sillHeight > 360
      runner.regiserWarning("#{sillHeight} inches seems like an unusually high sill height.")
    elsif sillHeight > 9999
      runner.regiserError("#{sillHeight} inches is above the measure limit for sill height.")
      return false
    end

    #setup OpenStudio units that we will need
    unit_sillHeight_ip = OpenStudio::createUnit("ft").get
    unit_sillHeight_si = OpenStudio::createUnit("m").get
    unit_area_ip = OpenStudio::createUnit("ft^2").get
    unit_area_si = OpenStudio::createUnit("m^2").get
    unit_cost_per_area_ip = OpenStudio::createUnit("1/ft^2").get #$/ft^2 does not work
    unit_cost_per_area_si = OpenStudio::createUnit("1/m^2").get
    
    #define starting units
    sillHeight_ip = OpenStudio::Quantity.new(sillHeight/12, unit_sillHeight_ip)

    #unit conversion
    sillHeight_si = OpenStudio::convert(sillHeight_ip, unit_sillHeight_si).get
    
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

    #hold data for initial condition
    starting_gross_ext_wall_area = 0.0 # includes windows and doors
    starting_ext_window_area = 0.0
    
    #hold data for final condition
    final_gross_ext_wall_area = 0.0 # includes windows and doors
    final_ext_window_area = 0.0    

    #flag for not applicable
    exterior_walls = false
    windows_added = false
    
    #flag to track notifications of zone multipliers
    space_warning_issued = []

    #loop through surfaces finding exterior walls with proper orientation
    surfaces = model.getSurfaces
    surfaces.each do |s|

      next if not s.surfaceType == "Wall"
      next if not s.outsideBoundaryCondition == "Outdoors"

      azimuth = OpenStudio::Quantity.new(s.azimuth,OpenStudio::createSIAngle)
      azimuth = OpenStudio::convert(azimuth,OpenStudio::createIPAngle).get.value

      if facade == "North"
        next if not (azimuth >= 315.0 or azimuth < 45.0)
      elsif facade == "East"
        next if not (azimuth >= 45.0 and azimuth < 135.0)
      elsif facade == "South"
        next if not (azimuth >= 135.0 and azimuth < 225.0)
      elsif facade == "West"
        next if not (azimuth >= 225.0 and azimuth < 315.0)
      else
        runner.registerError("Unexpected value of facade: " + facade + ".")
        return false
      end
      exterior_walls = true
      
      #get surface area adjusting for zone multiplier
      space = s.space
      if not space.empty?
        zone = space.get.thermalZone
      end      
      if not zone.empty?
        zone_multiplier = zone.get.multiplier
        if zone_multiplier > 1 and not space_warning_issued.include?(space.get.name.to_s)
          runner.registerInfo("Space #{space.get.name.to_s} in thermal zone #{zone.get.name.to_s} has a zone multiplier of #{zone_multiplier}. Adjusting area calculations.")
          space_warning_issued << space.get.name.to_s
        end
      else
        zone_multiplier = 1 #space is not in a thermal zone
        runner.registerWarning("Space #{space.get.name.to_s} is not in a thermal zone and won't be included in in the simulation. Windows will still be altered with an assumed zone multiplier of 1")
      end
      surface_gross_area = s.grossArea * zone_multiplier
    
      #loop through sub surfaces and add area including multiplier
      ext_window_area = 0            
      s.subSurfaces.each do |subSurface|
        ext_window_area = ext_window_area + subSurface.grossArea * subSurface.multiplier * zone_multiplier
        if subSurface.multiplier > 1
          runner.registerInfo("Sub-surface #{subSurface.name.to_s} in space #{space.get.name.to_s} has a sub-surface multiplier of #{subSurface.multiplier}. Adjusting area calculations.")
        end
      end
           
      starting_gross_ext_wall_area += surface_gross_area
      starting_ext_window_area += ext_window_area

      new_window = s.setWindowToWallRatio(wwr, sillHeight_si.value, true)
      if new_window.empty?
        runner.registerWarning("The requested window to wall ratio for surface '#{s.name}' was too large. Fenestration was not altered for this surface.")
      else
        windows_added = true
      end
    end #end of surfaces.each do

    #report initial condition wwr
    #the intial and final ratios does not currently account for either sub-surface or zone multipliers.
    starting_wwr = sprintf("%.02f",(starting_ext_window_area/starting_gross_ext_wall_area))
    runner.registerInitialCondition("The model's initial window to wall ratio for #{facade} facing exterior walls was #{starting_wwr}.")

    if not exterior_walls
      runner.registerAsNotApplicable("The model has no exterior #{facade.downcase} walls and was not altered")
      return true
    elsif not windows_added
      runner.registerAsNotApplicable("The model has exterior #{facade.downcase} walls, but no windows could be added with the requested window to wall ratio")
      return true
    end

    #data for final condition wwr
    surfaces = model.getSurfaces
    surfaces.each do |s|
      next if not s.surfaceType == "Wall"
      next if not s.outsideBoundaryCondition == "Outdoors"

      azimuth = OpenStudio::Quantity.new(s.azimuth,OpenStudio::createSIAngle)
      azimuth = OpenStudio::convert(azimuth,OpenStudio::createIPAngle).get.value

      if facade == "North"
        next if not (azimuth >= 315.0 or azimuth < 45.0)
      elsif facade == "East"
        next if not (azimuth >= 45.0 and azimuth < 135.0)
      elsif facade == "South"
        next if not (azimuth >= 135.0 and azimuth < 225.0)
      elsif facade == "West"
        next if not (azimuth >= 225.0 and azimuth < 315.0)
      else
        runner.registerError("Unexpected value of facade: " + facade + ".")
        return false
      end

      #get surface area adjusting for zone multiplier
      space = s.space
      if not space.empty?
        zone = space.get.thermalZone
      end      
      if not zone.empty?
        zone_multiplier = zone.get.multiplier
        if zone_multiplier > 1
        end
      else
        zone_multiplier = 1 #space is not in a thermal zone
      end
      surface_gross_area = s.grossArea * zone_multiplier
    
      #loop through sub surfaces and add area including multiplier
      ext_window_area = 0            
      s.subSurfaces.each do |subSurface| #onlky one and should have multiplier of 1
        ext_window_area = ext_window_area + subSurface.grossArea * subSurface.multiplier * zone_multiplier
      end     
      
      final_gross_ext_wall_area += surface_gross_area
      final_ext_window_area += ext_window_area
    end #end of surfaces.each do

    #check to see if the user included any cost in their arguments
    cost_included = false
    if not proposed_material_cost_si == 0 then cost_included = true end
    if not proposed_installation_cost_si == 0 then cost_included = true end
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

    #get building object to add cost to
    building = model.getBuilding

    #get delta in ft^2 for final - starting window area
    increase_window_area_si = OpenStudio::Quantity.new(final_ext_window_area - starting_ext_window_area, unit_area_si)
    increase_window_area_ip = OpenStudio::convert(increase_window_area_si, unit_area_ip).get
    
    #only add component cost line item objects if the user entered some non 0 cost values
    if cost_included
         
      #add component cost line item to building
      new_cost = OpenStudio::Model::ComponentCostLineItem.new(building)
      new_cost.setName("Measure Generated CCLI")
      
      #populate component cost line item (not sure if I need to set units for building object, of if always each)
      new_cost.setMaterialCost(increase_window_area_si.value * proposed_material_cost_si.value)     
      new_cost.setInstallationCost(increase_window_area_si.value * proposed_installation_cost_si.value)     
      recur_cost = new_cost.addComponentRecurringCost("Measure Generated RecurringCost","Maintenance",increase_window_area_si.value * proposed_recurring_cost_si.value,"CostPerEach")
      if expected_life >= 1
        new_cost.setExpectedLife(expected_life)
      else
        #leave blank to default to infinity
      end
      
    else    
      runner.registerInfo("Cost arguments were not provided, no cost objects were added to the model.")    
      
    end #end if cost included
   
    #get total cost to add
    if cost_included
      cost_total = new_cost.materialCost.get + new_cost.installationCost.get
    else
      cost_total = 0
    end
    
    #report final condition
    final_wwr = sprintf("%.02f",(final_ext_window_area/final_gross_ext_wall_area))
    runner.registerFinalCondition("The model's final window to wall ratio for #{facade} facing exterior walls is #{final_wwr}. Window area increased by #{pretty_numbers(increase_window_area_ip.value,0)} (ft^2) at a cost of $#{pretty_numbers(cost_total,0)}.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
SetWindowToWallRatioByFacade.new.registerWithApplication
