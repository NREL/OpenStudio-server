#start the measure
class SetInsulationRValueForExteriorWalls < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Set R-value of Insulation for Exterior Walls to a Specific Value"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make an argument insulation R-value
    r_value = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("r_value",true)
    r_value.setDisplayName("Insulation R-value (ft^2*h*R/Btu)")
    r_value.setDefaultValue(13.0)
    args << r_value

    #make an optional argument for baseline material cost
    baseline_material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("baseline_material_cost",false)
    baseline_material_cost.setDisplayName("Baseline Material Cost ($/ft^2)")
    args << baseline_material_cost

    #make an optional argument for proposed material cost
    proposed_material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_material_cost",false)
    proposed_material_cost.setDisplayName("Proposed Material Cost ($/ft^2)")
    args << proposed_material_cost

    #make an optional argument for baseline installation cost
    baseline_installation_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("baseline_installation_cost",false)
    baseline_installation_cost.setDisplayName("Baseline Installation Cost ($/ft^2)")
    args << baseline_installation_cost

    #make an optional argument for proposed installation cost
    proposed_installation_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_installation_cost",false)
    proposed_installation_cost.setDisplayName("Proposed Installation Cost ($/ft^2)")
    args << proposed_installation_cost

    #make an optional argument for baseline demolition cost
    baseline_demolition_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("baseline_demolition_cost",false)
    baseline_demolition_cost.setDisplayName("Baseline Demolition Cost ($/ft^2)")
    args << baseline_demolition_cost

    #make an optional argument for proposed demolition cost
    proposed_demolition_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_demolition_cost",false)
    proposed_demolition_cost.setDisplayName("Proposed Demolition Cost ($/ft^2)")
    args << proposed_demolition_cost

    #make an optional argument for baseline salvage value
    baseline_salvage_value = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("baseline_salvage_value",false)
    baseline_salvage_value.setDisplayName("Baseline Salvage Value ($/ft^2)")
    args << baseline_salvage_value

    #make an optional argument for proposed  salvage value
    proposed_salvage_value = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_salvage_value",false)
    proposed_salvage_value.setDisplayName("Proposed Salvage Value ($/ft^2)")
    args << proposed_salvage_value

    #make an optional argument for baseline recurring cost
    baseline_recurring_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("baseline_recurring_cost",false)
    baseline_recurring_cost.setDisplayName("Baseline Recurring Cost ($/ft^2)")
    args << baseline_recurring_cost

    #make an optional argument for proposed recurring cost
    proposed_recurring_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("proposed_recurring_cost",false)
    proposed_recurring_cost.setDisplayName("Proposed Recurring Cost ($/ft^2)")
    args << proposed_recurring_cost    
    
    #make an optional argument for expected life (single value for both baseline and proposed)
    #limit to integer vs. double
    expected_life = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("expected_life",false)
    expected_life.setDisplayName("Expected Life - Single Value for Baseline and Proposed (whole years)")
    args << expected_life    

    #populate string for choice argument
    retrofit_display_names = OpenStudio::StringVector.new
    retrofit_display_names << "New Construction"
    retrofit_display_names << "Retrofit"
    retrofit = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("retrofit", retrofit_display_names, true)
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
    r_value = runner.getDoubleArgumentValue("r_value",user_arguments)
    baseline_material_cost = runner.getOptionalDoubleArgumentValue("baseline_material_cost",user_arguments)
    proposed_material_cost = runner.getOptionalDoubleArgumentValue("proposed_material_cost",user_arguments)
    baseline_installation_cost = runner.getOptionalDoubleArgumentValue("baseline_installation_cost",user_arguments)
    proposed_installation_cost = runner.getOptionalDoubleArgumentValue("proposed_installation_cost",user_arguments)
    baseline_demolition_cost = runner.getOptionalDoubleArgumentValue("baseline_demolition_cost",user_arguments)
    proposed_demolition_cost = runner.getOptionalDoubleArgumentValue("proposed_demolition_cost",user_arguments)
    baseline_salvage_value = runner.getOptionalDoubleArgumentValue("baseline_salvage_value",user_arguments)
    proposed_salvage_value = runner.getOptionalDoubleArgumentValue("proposed_salvage_value",user_arguments)
    baseline_recurring_cost = runner.getOptionalDoubleArgumentValue("baseline_recurring_cost",user_arguments)
    proposed_recurring_cost = runner.getOptionalDoubleArgumentValue("proposed_recurring_cost",user_arguments)
    expected_life = runner.getOptionalIntegerArgumentValue("expected_life",user_arguments)
    retrofit = runner.getStringArgumentValue("retrofit",user_arguments)
    
    #set limit for minimum insulation. This is used to limit input and for inferring insulation layer in construction.
    min_expected_r_value = 1 #ip units

    #check the R-value for reasonableness
    if r_value < 0 or r_value > 500
      runner.registerError("The requested wall insulation R-value of #{r_value} ft^2*h*R/Btu was above the measure limit.")
      return false
    elsif r_value > 40
      runner.registerWarning("The requested wall insulation R-value of #{r_value} ft^2*h*R/Btu is abnormally high.")
    elsif r_value < min_expected_r_value
      runner.registerWarning("The requested wall insulation R-value of #{r_value} ft^2*h*R/Btu is abnormally low.")
    end

    #setup OpenStudio units that we will need
    unit_r_value_ip = OpenStudio::createUnit("ft^2*h*R/Btu").get
    unit_r_value_si = OpenStudio::createUnit("m^2*K/W").get
    unit_cost_per_area_ip = OpenStudio::createUnit("1/ft^2").get #$/ft^2 does not work
    unit_cost_per_area_si = OpenStudio::createUnit("1/m^2").get
    unit_area_ip = OpenStudio::createUnit("ft^2").get
    unit_area_si = OpenStudio::createUnit("m^2").get

    #define starting units
    r_value_ip = OpenStudio::Quantity.new(r_value, unit_r_value_ip)
    min_expected_r_value_ip = OpenStudio::Quantity.new(min_expected_r_value, unit_r_value_ip)

    #unit conversion of wall insulation from IP units (ft^2*h*R/Btu) to SI units (M^2*K/W)
    r_value_si = OpenStudio::convert(r_value_ip, unit_r_value_si).get
    min_expected_r_value_si = OpenStudio::convert(min_expected_r_value_ip, unit_r_value_si).get

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
      baseline_material_cost_si = OpenStudio::Quantity.new(0, unit_cost_per_area_si)     
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
      proposed_material_cost_si = OpenStudio::Quantity.new(0, unit_cost_per_area_si)       
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
      baseline_installation_cost_si = OpenStudio::Quantity.new(0, unit_cost_per_area_si)     
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
      proposed_installation_cost_si = OpenStudio::Quantity.new(0, unit_cost_per_area_si)     
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
      baseline_demolition_cost_si = OpenStudio::Quantity.new(0, unit_cost_per_area_si)        
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
      proposed_demolition_cost_si = OpenStudio::Quantity.new(0, unit_cost_per_area_si)        
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
      baseline_salvage_value_si = OpenStudio::Quantity.new(0, unit_cost_per_area_si)       
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
      proposed_salvage_value_si = OpenStudio::Quantity.new(0, unit_cost_per_area_si)        
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
      baseline_recurring_cost_si = OpenStudio::Quantity.new(0, unit_cost_per_area_si)         
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
      proposed_recurring_cost_si = OpenStudio::Quantity.new(0, unit_cost_per_area_si)       
    end
    
    #get optional values for expected_life, check for reasonablness, and convert to SI    
    if not expected_life.empty?
      if expected_life.get < 1
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

    # capital cost counter for use in final condition (does not include recurring costs)
    capital_cost_per_area = 0  
    
    #create an array of exterior walls and find range of starting construction R-value (not just insulation layer)
    surfaces = model.getSurfaces
    exterior_surfaces = []
    exterior_surface_constructions = []
    exterior_surface_construction_names = []
    ext_wall_resistance = []
    surfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Outdoors" and surface.surfaceType == "Wall"
        exterior_surfaces << surface
        ext_wall_const = surface.construction.get
        #only add construction if it hasn't been added yet
        if not exterior_surface_construction_names.include?(ext_wall_const.name.to_s)
          exterior_surface_constructions << ext_wall_const.to_Construction.get
        end
        exterior_surface_construction_names << ext_wall_const.name.to_s
        ext_wall_resistance << 1/ext_wall_const.thermalConductance.to_f
      end
    end

    # nothing will be done if there are no exterior surfaces
    if exterior_surfaces.empty?
      runner.registerAsNotApplicable("Model does not have any exterior walls, nothing will be changed.")
    end

    #report strings for initial condition
    initial_string = []    
    exterior_surface_constructions.uniq.each do |exterior_surface_construction|
      #unit conversion of roof insulation from SI units (M^2*K/W) to IP units (ft^2*h*R/Btu) 
      initial_conductance_si = OpenStudio::Quantity.new(1/exterior_surface_construction.thermalConductance.to_f, unit_r_value_si)
      initial_conductance_ip = OpenStudio::convert(initial_conductance_si, unit_r_value_ip).get
      initial_string << "#{exterior_surface_construction.name.to_s} (R-#{(sprintf "%.1f",initial_conductance_ip.value)})"
    end
    runner.registerInitialCondition("The building had #{initial_string.size} exterior wall constructions: #{initial_string.sort.join(", ")}.")

    #hashes to track constructions and materials made by the measure, to avoid duplicates
    constructions_hash_old_new = {}
    constructions_hash_new_old = {} #used to get netArea of new construction and then cost objects of construction it replaced
    materials_hash = {}
    
    #array of new constructions that are made, used for reporting final condition
    final_constructions_array = []
    
    #loop through all constructions and materials used on exterior walls, edit and clone
    exterior_surface_constructions.each do |exterior_surface_construction|
      construction_layers = exterior_surface_construction.layers
      max_thermal_resistance_material = ""
      max_thermal_resistance_material_index = ""
      counter = 0
      thermal_resistance_values = []

      #loop through construction layers and infer insulation layer/material
      construction_layers.each do |construction_layer|
        construction_layer_r_value = construction_layer.to_OpaqueMaterial.get.thermalResistance
        if not thermal_resistance_values.empty?
          if construction_layer_r_value > thermal_resistance_values.max
            max_thermal_resistance_material = construction_layer
            max_thermal_resistance_material_index = counter
          end
        end
        thermal_resistance_values << construction_layer_r_value
        counter = counter + 1
      end

      if not thermal_resistance_values.max > min_expected_r_value_si.value
        runner.registerWarning("Construction '#{exterior_surface_construction.name.to_s}' does not appear to have an insulation layer and was not altered.")
      else
        #clone the construction
        final_construction = exterior_surface_construction.clone(model)
        final_construction = final_construction.to_Construction.get
        final_construction.setName("#{exterior_surface_construction.name.to_s} adj ext wall insulation")
        final_constructions_array << final_construction

        #push to hashes
        constructions_hash_old_new[exterior_surface_construction.name.to_s] = final_construction
        constructions_hash_new_old[final_construction] = exterior_surface_construction #push the object to hash key vs. name        
    
        #only add component cost line item objects if the user entered some non 0 cost values
        if cost_included
             
          #add component cost line item to building
          new_cost = OpenStudio::Model::ComponentCostLineItem.new(final_construction)
          new_cost.setName("Measure Generated CCLI")
          
          #populate component cost line item (not sure if I need to set units for building object, of if always each)
          new_cost.setMaterialCost(proposed_material_cost_si.value - baseline_material_cost_si.value) 
          capital_cost_per_area = capital_cost_per_area + new_cost.materialCost.get
          new_cost.setInstallationCost(proposed_installation_cost_si.value - baseline_installation_cost_si.value)     
          capital_cost_per_area = capital_cost_per_area + new_cost.installationCost.get
          new_cost.setDemolitionCost(proposed_demolition_cost_si.value - baseline_demolition_cost_si.value)     
          new_cost.setSalvageValue(proposed_salvage_value_si.value - baseline_salvage_value_si.value)
          recur_cost = new_cost.addComponentRecurringCost("Measure Generated RecurringCost","Maintenance",proposed_recurring_cost_si.value - baseline_recurring_cost_si.value,"CostPerArea")
          #if expected life was not empty than set it in cost object
          if not expected_life.empty?
            new_cost.setExpectedLife(expected_life.get)
          else
            #leave blank to default to infinity
          end
          

          #add one time sunck costs for replaced objects if project is retrofit
          if retrofit == "Retrofit"
            retrofit_cost = OpenStudio::Model::ComponentCostLineItem.new(final_construction)
            retrofit_cost.setName("Measure Generated CCLI")
            retrofit_cost.setMaterialCost(baseline_material_cost_si.value - baseline_salvage_value_si.value)     
            capital_cost_per_area = capital_cost_per_area + retrofit_cost.materialCost.get
            retrofit_cost.setInstallationCost(baseline_installation_cost_si.value + baseline_demolition_cost_si.value)
            capital_cost_per_area = capital_cost_per_area + retrofit_cost.installationCost.get

            #calculate capital cost for new construction and retrofit workflow to use in final condition    
            one_time_retrofit_cost_si = OpenStudio::Quantity.new(retrofit_cost.materialCost.get + retrofit_cost.installationCost.get, unit_cost_per_area_si)
            one_time_retrofit_cost_ip = OpenStudio::convert(one_time_retrofit_cost_si, unit_cost_per_area_ip).get  

            runner.registerInfo("Added one time cost of #{pretty_numbers(one_time_retrofit_cost_ip.value)} ($/ft^2) to the design alternative to adjust for cost associated with the removal of #{exterior_surface_construction.name.to_s}.")            
          end
          
        else    
          runner.registerInfo("Cost arguments were not provided, no cost objects were added to the model.")    
          
        end #end if cost included        
        
        #find already cloned insulation material and link to construction
        target_material = max_thermal_resistance_material
        found_material = false
        materials_hash.each do |orig,new|
          if target_material.name.to_s == orig
            new_material = new
            materials_hash[max_thermal_resistance_material.name.to_s] = new_material
            final_construction.eraseLayer(max_thermal_resistance_material_index)
            final_construction.insertLayer(max_thermal_resistance_material_index,new_material)
            found_material = true
          end
        end

        #clone and edit insulation material and link to construction
        if found_material == false
          new_material = max_thermal_resistance_material.clone(model)
          new_material = new_material.to_OpaqueMaterial.get
          new_material.setName("#{max_thermal_resistance_material.name.to_s}_R-value #{r_value} (ft^2*h*R/Btu)")
          materials_hash[max_thermal_resistance_material.name.to_s] = new_material
          final_construction.eraseLayer(max_thermal_resistance_material_index)
          final_construction.insertLayer(max_thermal_resistance_material_index,new_material)
          runner.registerInfo("For construction'#{final_construction.name.to_s}', material'#{new_material.name.to_s}' was altered.")

          #edit insulation material
          new_material_matt = new_material.to_Material
          if not new_material_matt.empty?
            starting_thickness = new_material_matt.get.thickness
            target_thickness = starting_thickness * r_value_si.value / thermal_resistance_values.max
            final_thickness = new_material_matt.get.setThickness(target_thickness)
          end
          new_material_massless = new_material.to_MasslessOpaqueMaterial
          if not new_material_massless.empty?
            final_thermal_resistance = new_material_massless.get.setThermalResistance(r_value_si.value)
          end
          new_material_airgap = new_material.to_AirGap
          if not new_material_airgap.empty?
            final_thermal_resistance = new_material_airgap.get.setThermalResistance(r_value_si.value)
          end
        end #end of if found material is false
      end #end of if not thermal_resistance_values.max >
    end #end of loop through unique exterior wall constructions

    #loop through construction sets used in the model
    default_construction_sets = model.getDefaultConstructionSets
    default_construction_sets.each do |default_construction_set|
      if default_construction_set.directUseCount > 0
        default_surface_const_set = default_construction_set.defaultExteriorSurfaceConstructions
        if not default_surface_const_set.empty?
          starting_construction = default_surface_const_set.get.wallConstruction

          #creating new default construction set
          new_default_construction_set = default_construction_set.clone(model)
          new_default_construction_set = new_default_construction_set.to_DefaultConstructionSet.get
          new_default_construction_set.setName("#{default_construction_set.name.to_s} adj ext wall insulation")

          #create new surface set and link to construction set
          new_default_surface_const_set = default_surface_const_set.get.clone(model)
          new_default_surface_const_set = new_default_surface_const_set.to_DefaultSurfaceConstructions.get
          new_default_surface_const_set.setName("#{default_surface_const_set.get.name.to_s} adj ext wall insulation")
          new_default_construction_set.setDefaultExteriorSurfaceConstructions(new_default_surface_const_set)

          #use the hash to find the proper construction and link to new_default_surface_const_set
          target_const = new_default_surface_const_set.wallConstruction
          if not target_const.empty?
            target_const = target_const.get.name.to_s
            found_const_flag = false
            constructions_hash_old_new.each do |orig,new|
              if target_const == orig
                final_construction = new
                new_default_surface_const_set.setWallConstruction(final_construction)
                found_const_flag = true
              end
            end
            if found_const_flag == false # this should never happen but is just an extra test in case something goes wrong with the measure code
              runner.registerWarning("Measure couldn't find the construction named '#{target_const}' in the exterior surface hash.")
            end
          end

          #swap all uses of the old construction set for the new
          construction_set_sources = default_construction_set.sources
          construction_set_sources.each do |construction_set_source|
            building_source = construction_set_source.to_Building
            # if statement for each type of object than can use a DefaultConstructionSet
            if not building_source.empty?
              building_source = building_source.get
              building_source.setDefaultConstructionSet(new_default_construction_set)
            end
            building_story_source = construction_set_source.to_BuildingStory
            if not building_story_source.empty?
              building_story_source = building_story_source.get
              building_story_source.setDefaultConstructionSet(new_default_construction_set)
            end
            space_type_source = construction_set_source.to_SpaceType
            if not space_type_source.empty?
              space_type_source = space_type_source.get
              space_type_source.setDefaultConstructionSet(new_default_construction_set)
            end
            space_source = construction_set_source.to_Space
            if not space_source.empty?
              space_source = space_source.get
              space_source.setDefaultConstructionSet(new_default_construction_set)
            end
          end #end of construction_set_sources.each do

        end #end of if not default_surface_const_set.empty?
      end #end of if default_construction_set.directUseCount > 0
    end #end of loop through construction sets

    #link cloned and edited constructions for surfaces with hard assigned constructions
    exterior_surfaces.each do |exterior_surface|
      if not exterior_surface.isConstructionDefaulted and not exterior_surface.construction.empty?

        #use the hash to find the proper construction and link to surface
        target_const = exterior_surface.construction
        if not target_const.empty?
          target_const = target_const.get.name.to_s
          constructions_hash_old_new.each do |orig,new|
            if target_const == orig
              final_construction = new
              exterior_surface.setConstruction(final_construction)
            end
          end
        end

      end #end of if not exterior_surface.isConstructionDefaulted and not exterior_surface.construction.empty?
    end #end of exterior_surfaces.each do

    #report strings for final condition
    final_string = []   #not all exterior roof constructinos, but only new ones made. If  roof didn't have insulation and was not altered we don't want to show it 
    affected_area = 0
    final_constructions_array.each do |final_construction|
      #unit conversion of roof insulation from SI units (M^2*K/W) to IP units (ft^2*h*R/Btu) 
      final_conductance_si = OpenStudio::Quantity.new(1/final_construction.thermalConductance.to_f, unit_r_value_si)
      final_conductance_ip = OpenStudio::convert(final_conductance_si, unit_r_value_ip).get
      final_string << "#{final_construction.name.to_s} (R-#{(sprintf "%.1f",final_conductance_ip.value)})"
      affected_area = affected_area + final_construction.getNetArea
    end

    #ip construction area for reporting
    const_area_si = OpenStudio::Quantity.new(affected_area, unit_area_si)
    const_area_ip = OpenStudio::convert(const_area_si, unit_area_ip).get  

    #calculate capital cost for new construction and retrofit workflow to use in final condition    
    capital_cost_per_area_si = OpenStudio::Quantity.new(capital_cost_per_area, unit_cost_per_area_si)
    capital_cost_per_area_ip = OpenStudio::convert(capital_cost_per_area_si, unit_cost_per_area_ip).get  

    #report final condition
    runner.registerFinalCondition("The existing insulation for all insulated exterior walls constructions was modified to be R-#{r_value}. This was applied to #{pretty_numbers(const_area_ip.value,0)} (ft^2) of roof area at a cost of #{pretty_numbers(capital_cost_per_area_ip.value)} ($/ft^2}. After the change, the building had #{final_string.size} roof constructions: #{final_string.sort.join(", ")}.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
SetInsulationRValueForExteriorWalls.new.registerWithApplication
