#start the measure
class AddOverhangsByProjectionFactor < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Add Overhangs by Projection Factor"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new


    #make an argument for projection factor
    projection_factor = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("projection_factor",true)
    projection_factor.setDisplayName("Projection Factor (overhang depth / window height)")
    projection_factor.setDefaultValue(0.5)
    args << projection_factor

    #make choice argument for facade
    choices = OpenStudio::StringVector.new
    choices << "North"
    choices << "East"
    choices << "South"
    choices << "West"
    facade = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("facade", choices)
    facade.setDisplayName("Cardinal Direction")
    facade.setDefaultValue("South")
    args << facade

    #make an argument for deleting all existing space shading in the model
    remove_ext_space_shading = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_ext_space_shading",true)
    remove_ext_space_shading.setDisplayName("Remove Existing Space Shading Surfaces From the Model?")
    remove_ext_space_shading.setDefaultValue(false)
    args << remove_ext_space_shading

    #populate choice argument for constructions that are applied to surfaces in the model
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
      #only include if construction is not used on surface
      if not value.isFenestration
        construction_handles << value.handle.to_s
        construction_display_names << key
      end
    end

    #make an argument for construction
    construction = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("construction", construction_handles, construction_display_names,false)
    construction.setDisplayName("Optionally Choose a Construction for the Overhangs.")
    args << construction


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
    projection_factor = runner.getDoubleArgumentValue("projection_factor",user_arguments)
    facade = runner.getStringArgumentValue("facade",user_arguments)
    remove_ext_space_shading = runner.getBoolArgumentValue("remove_ext_space_shading",user_arguments)
    construction = runner.getOptionalWorkspaceObjectChoiceValue("construction",user_arguments,model)

    #check reasonableness of fraction
    if projection_factor < 0
      runner.registerError("Please enter a positive number for the projection factor.")
      return false
    elsif projection_factor < 0.1
      runner.registerWarning("The requested projection factor of #{projection_factor} seems unusually small.")
    elsif projection_factor > 5
      runner.registerWarning("The requested projection factor of #{projection_factor} seems unusually large.")
    end

    #check the construction for reasonableness
    construction_chosen = true
    if construction.empty?
      handle = runner.getOptionalStringArgumentValue("construction",user_arguments)
      if handle.empty?
        runner.registerInfo("No construction was chosen.")
        construction_chosen = false
      else
        runner.registerError("The selected construction with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end

    else
      if not construction.get.to_Construction.empty?
        construction = construction.get.to_Construction.get
      else
        runner.registerError("Script Error - argument not showing up as construction.")
        return false
      end
    end  #end of if construction.empty?

    #helper to make numbers pretty (converts 4125001.25641 to 4,125,001.26 or 4,125,001). The definition be called through this measure.
    def neat_numbers(number, roundto = 2) #round to 0 or 2)
      if roundto == 2
        number = sprintf "%.2f", number
      else
        number = number.round
      end
      #regex to add commas
      number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
    end #end def neat_numbers

    #helper to make it easier to do unit conversions on the fly.  The definition be called through this measure.
    def unit_helper(number,from_unit_string,to_unit_string)
      converted_number = OpenStudio::convert(OpenStudio::Quantity.new(number, OpenStudio::createUnit(from_unit_string).get), OpenStudio::createUnit(to_unit_string).get).get.value
    end

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

    #counter for year 0 capital costs
    yr0_capital_totalCosts = 0

    #get initial construction costs and multiply by -1
    yr0_capital_totalCosts +=  get_total_costs_for_objects(model.getConstructions)*-1

    #reporting initial condition of model
    number_of_exist_space_shading_surf = 0
    shading_groups = model.getShadingSurfaceGroups
    shading_groups.each do |shading_group|
      if shading_group.shadingSurfaceType == "Space"
        number_of_exist_space_shading_surf = number_of_exist_space_shading_surf + shading_group.shadingSurfaces.size
      end
    end
    runner.registerInitialCondition("The initial building had #{number_of_exist_space_shading_surf} space shading surfaces.")

    #delete all space shading groups if requested
    if remove_ext_space_shading and number_of_exist_space_shading_surf > 0
      shading_groups.each do |shading_group|
        if shading_group.shadingSurfaceType == "Space"
          shading_group.remove
        end
        runner.registerWarning("Removed all existing space shading surface groups from the model.")
      end
    end

    #flag for not applicable
    overhang_added = false

    #loop through surfaces finding exterior walls with proper orientation
    sub_surfaces = model.getSubSurfaces
    sub_surfaces.each do |s|

      next if not s.outsideBoundaryCondition == "Outdoors"
      next if s.subSurfaceType == "Skylight"
      next if s.subSurfaceType == "Door"
      next if s.subSurfaceType == "GlassDoor"
      next if s.subSurfaceType == "OverheadDoor"
      next if s.subSurfaceType == "TubularDaylightDome"
      next if s.subSurfaceType == "TubularDaylightDiffuser"

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

      #delete existing overhang for this window if it exists from previously run measure
      shading_groups.each do |shading_group|
        shading_s = shading_group.shadingSurfaces
        shading_s.each do |ss|
          if ss.name.to_s == "#{s.name.to_s} - Overhang"
            ss.remove
            runner.registerWarning("Removed pre-existing window shade named '#{ss.name}'.")
          end
        end
      end

      new_overhang = s.addOverhangByProjectionFactor(projection_factor, 0)
      if new_overhang.empty?
        ok = runner.registerWarning("Unable to add overhang to " + s.briefDescription +
                 " with projection factor " + projection_factor.to_s + " and offset " + offset.to_s + ".")
        return false if not ok
      else
        new_overhang.get.setName("#{s.name} - Overhang")
        runner.registerInfo("Added overhang " + new_overhang.get.briefDescription + " to " +
            s.briefDescription + " with projection factor " + projection_factor.to_s +
            " and offset " + "0" + ".")
        if construction_chosen
          if not construction.to_Construction.empty?
            new_overhang.get.setConstruction(construction)
          end
        end
        overhang_added = true
      end

    end #end sub_surfaces.each do |s|

    if not overhang_added
      runner.registerAsNotApplicable("The model has exterior #{facade.downcase} walls, but no windows were found to add overhangs to.")
      return true
    end

    #get final construction costs and multiply
    yr0_capital_totalCosts +=  get_total_costs_for_objects(model.getConstructions)

    #reporting initial condition of model
    number_of_final_space_shading_surf = 0
    final_shading_groups = model.getShadingSurfaceGroups
    final_shading_groups.each do |shading_group|
      number_of_final_space_shading_surf = number_of_final_space_shading_surf + shading_group.shadingSurfaces.size
    end
    runner.registerFinalCondition("The final building has #{number_of_final_space_shading_surf} space shading surfaces. Initial capital costs associated with the improvements are $#{neat_numbers(yr0_capital_totalCosts,0)}.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AddOverhangsByProjectionFactor.new.registerWithApplication