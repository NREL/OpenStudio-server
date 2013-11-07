#start the measure
class ReduceNightTimeLightingLoads < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Reduce Night Time Lighting Loads"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make a choice argument for load def with one or more instances
    lights_def_handles = OpenStudio::StringVector.new
    lights_def_display_names = OpenStudio::StringVector.new

    #putting load defs and names into hash
    light_def_args = model.getLightsDefinitions
    light_def_args_hash = {}
    light_def_args.each do |light_def_arg|
      light_def_args_hash[light_def_arg.name.to_s] = light_def_arg
    end

    #looping through sorted hash of load defs
    light_def_args_hash.sort.map do |key,value|
      if value.instances.size > 0
        lights_def_handles << value.handle.to_s
        lights_def_display_names << key
      end
    end

    #make an argument for electric equipment definition
    lights_def = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("lights_def", lights_def_handles, lights_def_display_names)
    lights_def.setDisplayName("Pick a Lighting Definition From the Model (schedules using this will be altered)")
    args << lights_def

    #make an argument for fractional value during specified time
    fraction_value = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fraction_value",true)
    fraction_value.setDisplayName("Fractional Value for Night Time Load")
    fraction_value.setDefaultValue(0.1)
    args << fraction_value

    #apply to weekday
    apply_weekday = OpenStudio::Ruleset::OSArgument::makeBoolArgument("apply_weekday",true)
    apply_weekday.setDisplayName("Apply Schedule Changes to Weekday and Default Profiles?")
    apply_weekday.setDefaultValue(true)
    args << apply_weekday

    #weekday start time
    start_weekday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("start_weekday",true)
    start_weekday.setDisplayName("Weekday/Default Time to Start Night Time Fraction(24hr, use decimal for sub hour).")
    start_weekday.setDefaultValue(18.0)
    args << start_weekday

    #weekday end time
    end_weekday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("end_weekday",true)
    end_weekday.setDisplayName("Weekday/Default Time to End Night Time Fraction(24hr, use decimal for sub hour).")
    end_weekday.setDefaultValue(9.0)
    args << end_weekday

    #apply to saturday
    apply_saturday = OpenStudio::Ruleset::OSArgument::makeBoolArgument("apply_saturday",true)
    apply_saturday.setDisplayName("Apply schedule changes to Saturdays?")
    apply_saturday.setDefaultValue(true)
    args << apply_saturday

    #saturday start time
    start_saturday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("start_saturday",true)
    start_saturday.setDisplayName("Saturday Time to Start Night Time Fraction(24hr, use decimal for sub hour).")
    start_saturday.setDefaultValue(18.0)
    args << start_saturday

    #saturday end time
    end_saturday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("end_saturday",true)
    end_saturday.setDisplayName("Saturday Time to End Night Time Fraction(24hr, use decimal for sub hour).")
    end_saturday.setDefaultValue(9.0)
    args << end_saturday

    #apply to sunday
    apply_sunday = OpenStudio::Ruleset::OSArgument::makeBoolArgument("apply_sunday",true)
    apply_sunday.setDisplayName("Apply Schedule Changes to Sundays?")
    apply_sunday.setDefaultValue(true)
    args << apply_sunday

    #sunday start time
    start_sunday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("start_sunday",true)
    start_sunday.setDisplayName("Sunday Time to Start Night Time Fraction(24hr, use decimal for sub hour).")
    start_sunday.setDefaultValue(18.0)
    args << start_sunday

    #sunday end time
    end_sunday = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("end_sunday",true)
    end_sunday.setDisplayName("Sunday Time to End Night Time Fraction(24hr, use decimal for sub hour).")
    end_sunday.setDefaultValue(9.0)
    args << end_sunday

    #make an argument for material and installation cost
    material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("material_cost",true)
    material_cost.setDisplayName("Material and Installation Costs per Light Quantity ($).")
    material_cost.setDefaultValue(0.0)
    args << material_cost

    #make an argument for duration in years until costs start
    years_until_costs_start = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("years_until_costs_start",true)
    years_until_costs_start.setDisplayName("Years Until Costs Start (whole years).")
    years_until_costs_start.setDefaultValue(0)
    args << years_until_costs_start

    #make an argument for expected life
    expected_life = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("expected_life",true)
    expected_life.setDisplayName("Expected Life (whole years).")
    expected_life.setDefaultValue(20)
    args << expected_life

    #make an argument for o&m cost
    om_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("om_cost",true)
    om_cost.setDisplayName("O & M Costs Costs per Light Quantity ($).")
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
    lights_def = runner.getOptionalWorkspaceObjectChoiceValue("lights_def",user_arguments,model)
    fraction_value = runner.getDoubleArgumentValue("fraction_value",user_arguments)
    apply_weekday = runner.getBoolArgumentValue("apply_weekday",user_arguments)
    start_weekday = runner.getDoubleArgumentValue("start_weekday",user_arguments)
    end_weekday = runner.getDoubleArgumentValue("end_weekday",user_arguments)
    apply_saturday = runner.getBoolArgumentValue("apply_saturday",user_arguments)
    start_saturday = runner.getDoubleArgumentValue("start_saturday",user_arguments)
    end_saturday = runner.getDoubleArgumentValue("end_saturday",user_arguments)
    apply_sunday = runner.getBoolArgumentValue("apply_sunday",user_arguments)
    start_sunday = runner.getDoubleArgumentValue("start_sunday",user_arguments)
    end_sunday = runner.getDoubleArgumentValue("end_sunday",user_arguments)
    material_cost = runner.getDoubleArgumentValue("material_cost",user_arguments)
    years_until_costs_start = runner.getIntegerArgumentValue("years_until_costs_start",user_arguments)
    expected_life = runner.getIntegerArgumentValue("expected_life",user_arguments)
    om_cost = runner.getDoubleArgumentValue("om_cost",user_arguments)
    om_frequency = runner.getIntegerArgumentValue("om_frequency",user_arguments)

    #check the lights_def for reasonableness
    if lights_def.empty?
      test = runner.getStringArgumentValue("lights_def",user_arguments)
      if test.empty?
        runner.registerError("No Lighting Definition was chosen.")
      else
        runner.registerError("A Lighting Definition with handle '#{lights_def}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not lights_def.get.to_LightsDefinition.empty?
        lights_def = lights_def.get.to_LightsDefinition.get
      else
        runner.registerError("Script Error - argument not showing up as lights definition.")
        return false
      end
    end

    #check the fraction for reasonableness
    if not 0 <= fraction_value and fraction_value <= 1
      runner.registerError("Fractional value needs to be between or equal to 0 and 1.")
      return false
    end

    #check start_weekday for reasonableness and round to 15 minutes
    if not 0 <= start_weekday and start_weekday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24")
      return false
    else
      rounded_start_weekday = ((start_weekday*4).round)/4.0
      if not start_weekday == rounded_start_weekday
        runner.registerInfo("Weekday start time rounded to nearest 15 minutes: #{rounded_start_weekday}")
      end
      wk_after_hour = rounded_start_weekday.truncate
      wk_after_min = (rounded_start_weekday - wk_after_hour)*60
      wk_after_min = wk_after_min.to_i
    end

    #check end_weekday for reasonableness and round to 15 minutes
    if not 0 <= end_weekday and end_weekday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    elsif end_weekday > start_weekday
      runner.registerError("Please enter an end time earlier in the day than start time.")
      return false
    else
      rounded_end_weekday = ((end_weekday*4).round)/4.0
      if not end_weekday == rounded_end_weekday
        runner.registerInfo("Weekday end time rounded to nearest 15 minutes: #{rounded_end_weekday}")
      end
      wk_before_hour = rounded_end_weekday.truncate
      wk_before_min = (rounded_end_weekday - wk_before_hour)*60
      wk_before_min = wk_before_min.to_i
    end

    #check start_saturday for reasonableness and round to 15 minutes
    if not 0 <= start_saturday and start_saturday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    else
      rounded_start_saturday = ((start_saturday*4).round)/4.0
      if not start_saturday == rounded_start_saturday
        runner.registerInfo("Saturday start time rounded to nearest 15 minutes: #{rounded_start_saturday}")
      end
      sat_after_hour = rounded_start_saturday.truncate
      sat_after_min = (rounded_start_saturday - sat_after_hour)*60
      sat_after_min = sat_after_min.to_i
    end

    #check end_saturday for reasonableness and round to 15 minutes
    if not 0 <= end_saturday and end_saturday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    elsif end_saturday > start_saturday
      runner.registerError("Please enter an end time earlier in the day than start time.")
      return false
    else
      rounded_end_saturday = ((end_saturday*4).round)/4.0
      if not end_saturday == rounded_end_saturday
        runner.registerInfo("Saturday end time rounded to nearest 15 minutes: #{rounded_end_saturday}")
      end
      sat_before_hour = rounded_end_saturday.truncate
      sat_before_min = (rounded_end_saturday - sat_before_hour)*60
      sat_before_min = sat_before_min.to_i
    end

    #check start_sunday for reasonableness and round to 15 minutes
    if not 0 <= start_sunday and start_sunday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    else
      rounded_start_sunday = ((start_sunday*4).round)/4.0
      if not start_sunday == rounded_start_sunday
        runner.registerInfo("Sunday start time rounded to nearest 15 minutes: #{rounded_start_sunday}")
      end
      sun_after_hour = rounded_start_sunday.truncate
      sun_after_min = (rounded_start_sunday - sun_after_hour)*60
      sun_after_min = sun_after_min.to_i
    end

    #check end_sunday for reasonableness and round to 15 minutes
    if not 0 <= end_sunday and end_sunday <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    elsif end_sunday > start_sunday
      runner.registerError("Please enter an end time earlier in the day than start time.")
      return false
    else
      rounded_end_sunday = ((end_sunday*4).round)/4.0
      if not end_sunday == rounded_end_sunday
        runner.registerInfo("Sunday end time rounded to nearest 15 minutes: #{rounded_end_sunday}")
      end
      sun_before_hour = rounded_end_sunday.truncate
      sun_before_min = (rounded_end_sunday - sun_before_hour)*60
      sun_before_min = sun_before_min.to_i
    end

    #set flags to use later
    costs_requested = false

    #check costs for reasonableness
    if material_cost.abs + om_cost.abs == 0
      runner.registerInfo("No costs were requested for #{lights_def.name}.")
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

    #breakup fractional values
    wk_before_value = fraction_value
    wk_after_value = fraction_value
    sat_before_value = fraction_value
    sat_after_value = fraction_value
    sun_before_value = fraction_value
    sun_after_value = fraction_value

    lights_schs = {}
    lights_sch_names = []
    reduced_lights_schs = {}

    #get instances of definition
    lighting_instances = model.getLightss
    lighting_instances_using_def = []

    #get schedules for equipment instances that user the picked
    lighting_instances.each do |light|
      next unless light.lightsDefinition == lights_def
      lighting_instances_using_def << light
      if not light.schedule.empty?
        lights_sch = light.schedule.get
        lights_schs[lights_sch.name.to_s] = lights_sch
        lights_sch_names << lights_sch.name.to_s
      end
    end

    #reporting initial condition of model
    runner.registerInitialCondition("The initial model had #{lighting_instances_using_def.size} instances of '#{lights_def.name}' load definition.")

    #loop through the unique list of lighting schedules, cloning
    #and reducing schedule fraction before and after the specified times
    lights_sch_names.uniq.each do |lights_sch_name|
      lights_sch = lights_schs[lights_sch_name]
      if not lights_sch.to_ScheduleRuleset.empty?
        new_lights_sch = lights_sch.clone(model).to_ScheduleRuleset.get
        new_lights_sch.setName("#{lights_sch_name} NightLightingControl")
        reduced_lights_schs[lights_sch_name] = new_lights_sch
        new_lights_sch = new_lights_sch.to_ScheduleRuleset.get

        #method to reduce the values in a day schedule to a given number before and after a given time
        def reduce_schedule(day_sch, before_hour, before_min, before_value, after_hour, after_min, after_value)
            before_time = OpenStudio::Time.new(0, before_hour, before_min, 0)
            after_time = OpenStudio::Time.new(0, after_hour, after_min, 0)
            day_end_time = OpenStudio::Time.new(0, 24, 0, 0)
            original_value_at_after_time = day_sch.getValue(after_time)
            day_sch.addValue(before_time,before_value)
            day_sch.addValue(after_time, original_value_at_after_time)
            times = day_sch.times
            values = day_sch.values
            day_sch.clearValues
            new_times = []
            new_values = []
            for i in 0..(values.length - 1)
              if times[i] >= before_time and times[i] <= after_time
                new_times << times[i]
                new_values << values[i]
              end
            end
            #add the value for the time period from after time to end of the day
            new_times << day_end_time
            new_values << after_value
            for i in 0..(new_values.length - 1)
              day_sch.addValue(new_times[i], new_values[i])
            end
          end #end reduce schedule

        #reduce default schedule and weekdays
        new_lights_sch.scheduleRules.each do |sch_rule|
          if apply_weekday
            if sch_rule.applyMonday or sch_rule.applyTuesday or sch_rule.applyWednesday or sch_rule.applyThursday or sch_rule.applyFriday
              reduce_schedule(sch_rule.daySchedule, wk_before_hour, wk_before_min, wk_before_value, wk_after_hour, wk_after_min, wk_after_value)
              reduce_schedule(new_lights_sch.defaultDaySchedule, wk_before_hour, wk_before_min, wk_before_value, wk_after_hour, wk_after_min, wk_after_value)
            end
          end
        end

        #reduce saturdays
        new_lights_sch.scheduleRules.each do |sch_rule|
          if apply_saturday and sch_rule.applySaturday
            if sch_rule.applyMonday or sch_rule.applyTuesday or sch_rule.applyWednesday or sch_rule.applyThursday or sch_rule.applyFriday
              runner.registerWarning("Rule #{sch_rule.name} for  schedule '#{new_lights_sch.name}' was already edited for weekdays. It also applies to Saturdays but will follow setup values for weekdays.")
            else
              reduce_schedule(sch_rule.daySchedule, sat_before_hour, sat_before_min, sat_before_value, sat_after_hour, sat_after_min, sat_after_value)
            end
          end
        end

        #reduce sundays
        new_lights_sch.scheduleRules.each do |sch_rule|
          if apply_sunday and sch_rule.applySunday
            if sch_rule.applyMonday or sch_rule.applyTuesday or sch_rule.applyWednesday or sch_rule.applyThursday or sch_rule.applyFriday
              runner.registerWarning("Rule #{sch_rule.name} for schedule '#{new_lights_sch.name}' was already edited for weekdays. It also applies to Saturdays but will follow setup values for weekdays.")
            elsif sch_rule.applySaturday
              runner.registerWarning("Rule #{sch_rule.name} for schedule '#{new_lights_sch.name}' was already edited for saturdays. It also applies to Sundays but will follow setup values for weekdays.")
            else
              reduce_schedule(sch_rule.daySchedule, sun_before_hour, sun_before_min, sun_before_value, sun_after_hour, sun_after_min, sun_after_value)
            end
          end
        end

      else
        runner.registerWarning("Schedule '#{lights_sch_name}' isn't a ScheduleRuleset object and won't be altered by this measure.")
      end #end of if not new_lights_sch.to_ScheduleRuleset.empty?
    end #end of lights_sch_names.uniq.each do

    #loop through all lighting instances, replacing old equip schedules with the reduced schedules
    lighting_instances_using_def.each do |light|
      if light.schedule.empty?
        runner.registerWarning("There was no schedule assigned for the light object named '#{light.name}. No schedule was added.'")
      else
        old_lights_sch_name = light.schedule.get.name.to_s
        if reduced_lights_schs[old_lights_sch_name]
          light.setSchedule(reduced_lights_schs[old_lights_sch_name])
          runner.registerInfo("Schedule '#{reduced_lights_schs[old_lights_sch_name].name}' was edited for the electric equipment object named '#{light.name}'")
        end
      end
    end


    #na if no schedules to change
    if lights_sch_names.uniq.size == 0
      runner.registerNotAsApplicable("There are no schedules to change.")
    end

    measure_cost = 0

    #add lifeCycleCost objects if there is a non-zero value in one of the cost arguments
    building = model.getBuilding
    if costs_requested == true
      quantity = lights_def.quantity
      #adding new cost items
      lcc_mat = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Mat - #{lights_def.name} night reduction", building, material_cost * quantity, "CostPerEach", "Construction", expected_life, years_until_costs_start)
      lcc_om = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_OM - #{lights_def.name} night reduction", building, om_cost * quantity, "CostPerEach", "Maintenance", om_frequency, 0)
      measure_cost =  material_cost * quantity
    end #end of costs_requested == true


    #reporting final condition of model
    runner.registerFinalCondition("#{lights_sch_names.uniq.size} schedule(s) were edited. The cost for the measure is #{neat_numbers(measure_cost,0)}.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
ReduceNightTimeLightingLoads.new.registerWithApplication
