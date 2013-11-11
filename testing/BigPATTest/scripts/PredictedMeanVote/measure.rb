#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class PredictedMeanVote < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Predicted Mean Vote"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make a bool argument for ASHRAE 55 Comfort Warnings
    comfortWarnings = OpenStudio::Ruleset::OSArgument::makeBoolArgument("comfortWarnings",true)
    comfortWarnings.setDisplayName("Enable ASHRAE 55 Comfort Warnings?")
    comfortWarnings.setDefaultValue(false)
    args << comfortWarnings

    #make a choice argument for Mean Radiant Temperature Calculation Type
    chs = OpenStudio::StringVector.new
    chs << "ZoneAveraged"
    chs << "SurfaceWeighted"
    #chs << "AngleFactor" # I disabled this choice unless we expose the Surface Name/Angle Factor List Name field.
    meanRadiantCalcType = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('meanRadiantCalcType', chs, true)
    meanRadiantCalcType.setDisplayName("Mean Radiant Temperature Calculation Type.")
    meanRadiantCalcType.setDefaultValue("ZoneAveraged")
    args << meanRadiantCalcType

    #populate raw choice argument for schedules
    schedule_handles = OpenStudio::StringVector.new
    schedule_display_names = OpenStudio::StringVector.new

    #putting raw schedules and names into hash
    schedule_args = model.getSchedules
    schedule_args_hash = {}
    schedule_args.each do |schedule_arg|
      schedule_args_hash[schedule_arg.name.to_s] = schedule_arg
    end

    #populate choice argument for fractional schedules
    fractional_schedule_handles = OpenStudio::StringVector.new
    fractional_schedule_display_names = OpenStudio::StringVector.new

    #looping through sorted hash of schedules to find fractional schedules
    schedule_args_hash.sort.map do |key,value|
      next if value.scheduleTypeLimits.empty?
      if value.scheduleTypeLimits.get.unitType == "Dimensionless" and not value.scheduleTypeLimits.get.lowerLimitValue.empty? and not value.scheduleTypeLimits.get.upperLimitValue.empty?
        next if not value.scheduleTypeLimits.get.lowerLimitValue.get == 0.0
        next if not value.scheduleTypeLimits.get.upperLimitValue.get == 1.0
        fractional_schedule_handles << value.handle.to_s
        fractional_schedule_display_names << key
      end
    end

    #make a choice schedule for Work Efficiency Schedule
    workEfficiencySchedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("workEfficiencySchedule",fractional_schedule_handles, fractional_schedule_display_names,true)
    workEfficiencySchedule.setDisplayName("Choose a Work Efficiency Schedule.")
    # I don't offer a default here because there will be many fractional schedules. I want to user to choose
    args << workEfficiencySchedule

    #populate choice argument for clothing insulation schedules
    clothing_schedule_handles = OpenStudio::StringVector.new
    clothing_schedule_display_names = OpenStudio::StringVector.new

    #looping through sorted hash of schedules to find clothing insulation schedules
    schedule_args_hash.sort.map do |key,value|
      next if value.scheduleTypeLimits.empty?
      if value.scheduleTypeLimits.get.unitType == "ClothingInsulation"
        clothing_schedule_handles << value.handle.to_s
        clothing_schedule_display_names << key
      end
    end

    #make a choice argument for Clothing Insulation Schedule Name
    clothingSchedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("clothingSchedule",clothing_schedule_handles, clothing_schedule_display_names,true)
    clothingSchedule.setDisplayName("Choose a Clothing Insulation Schedule.")
    if clothing_schedule_display_names.size > 0
      clothingSchedule.setDefaultValue(clothing_schedule_display_names[0]) #normally I don't default model choice list, but since often there might be just one I decided to default this.
    end
    args << clothingSchedule

    #populate choice argument for air velocity schedules
    airVelocity_schedule_handles = OpenStudio::StringVector.new
    airVelocity_schedule_display_names = OpenStudio::StringVector.new

    #looping through sorted hash of schedules to find air velocity schedules
    schedule_args_hash.sort.map do |key,value|
      next if value.scheduleTypeLimits.empty?
      if value.scheduleTypeLimits.get.unitType == "Velocity"
        airVelocity_schedule_handles << value.handle.to_s
        airVelocity_schedule_display_names << key
      end
    end

    #make a choice argument for Air Velocity Schedule Name
    airVelocitySchedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("airVelocitySchedule",airVelocity_schedule_handles, airVelocity_schedule_display_names,true)
    airVelocitySchedule.setDisplayName("Choose an Air Velocity Schedule.")
    if airVelocity_schedule_display_names.size > 0
      airVelocitySchedule.setDefaultValue(airVelocity_schedule_display_names[0]) #normally I don't default model choice list, but since often there might be just one I decided to default this.
    end
    args << airVelocitySchedule

    #hard code Thermal Comfort Model Type to Fanger, but could add argument in the future.

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
    comfortWarnings = runner.getBoolArgumentValue("comfortWarnings",user_arguments)
    meanRadiantCalcType = runner.getStringArgumentValue("meanRadiantCalcType",user_arguments)
    workEfficiencySchedule = runner.getOptionalWorkspaceObjectChoiceValue("workEfficiencySchedule",user_arguments,model) #model is passed in because of argument type
    clothingSchedule = runner.getOptionalWorkspaceObjectChoiceValue('clothingSchedule',user_arguments, model)
    airVelocitySchedule = runner.getOptionalWorkspaceObjectChoiceValue('airVelocitySchedule',user_arguments, model)

    #check the schedules for reasonableness
    if clothingSchedule.empty? or  airVelocitySchedule.empty? or workEfficiencySchedule.empty?
      handle = runner.getStringArgumentValue("construction",user_arguments)
      if handle.empty?
        runner.registerError("One of the required schedules was not chosen.")
      else
        runner.registerError("One of the selected schedules was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if clothingSchedule.get.to_Schedule.empty? or airVelocitySchedule.get.to_Schedule.empty? or workEfficiencySchedule.get.to_Schedule.empty?
        runner.registerError("Script Error - one of the schedule arguments is not showing up as an argument.")
        return false
      else
        workEfficiencySchedule = workEfficiencySchedule.get.to_Schedule.get
        clothingSchedule = clothingSchedule.get.to_Schedule.get
        airVelocitySchedule = airVelocitySchedule.get.to_Schedule.get
      end
    end  #end of if schedules.empty?

    #get people
    people_defs = model.getPeopleDefinitions
    people_instances = model.getPeoples

    #reporting initial condition of model
    starting_spaces = model.getSpaces
    runner.registerInitialCondition("The building started with #{people_defs.size} people definitions.")

    #loop through people
    people_def_counter = 0
    people_defs.sort.each do |people_def|
      next if not people_def.instances.size > 0
      people_def_counter += 1
      runner.registerInfo("Editing '#{people_def.name}'")
      people_def.setEnableASHRAE55ComfortWarnings(comfortWarnings)
      people_def.setMeanRadiantTemperatureCalculationType(meanRadiantCalcType)
      people_def.setThermalComfortModelType(0,"Fanger")
    end

    #loop through people instances
    people_instances.each do |people_instance|
      runner.registerInfo("Assigning Schedules for '#{people_instance.name}'")
      people_instance.setWorkEfficiencySchedule(workEfficiencySchedule)
      people_instance.setClothingInsulationSchedule(clothingSchedule)
      people_instance.setAirVelocitySchedule(airVelocitySchedule)
    end

    #array of output variables to use
    outputVariableArray = []
    #these work on EnergyPlus 7.2
    outputVariableArray << "FangerPMV"
    outputVariableArray << "FangerPPD"
    outputVariableArray << "Time Not Comfortable Summer Clothes"
    outputVariableArray << "Time Not Comfortable Winter Clothes"
    outputVariableArray << "Time Not Comfortable Summer Or Winter Clothes"
    #these work on EnergyPlus 8.0
    outputVariableArray << "Zone Thermal Comfort Fanger Model PMV"
    outputVariableArray << "Zone Thermal Comfort Fanger Model PPD"
    outputVariableArray << "Zone Thermal Comfort ASHRAE 55 Simple Model Summer Clothes Not Comfortable Time"
    outputVariableArray << "Zone Thermal Comfort ASHRAE 55 Simple Model Winter Clothes Not Comfortable Time"
    outputVariableArray << "Zone Thermal Comfort ASHRAE 55 Simple Model Summer or Winter Clothes Not Comfortable Time"

    #add output variable objects
    runner.registerInfo("Adding zone output variables for Fanger PMV, Fanger PPD, and ASHRAE 55")
    outputVariableArray.each do |variable|
      outputVariable = OpenStudio::Model::OutputVariable.new(variable,model)
      outputVariable.setReportingFrequency("hourly")
    end

    #reporting final condition of model
    finishing_spaces = model.getSpaces
    runner.registerFinalCondition("#{people_def_counter} people definitions and #{people_instances.size} people instances were altered.")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
PredictedMeanVote.new.registerWithApplication