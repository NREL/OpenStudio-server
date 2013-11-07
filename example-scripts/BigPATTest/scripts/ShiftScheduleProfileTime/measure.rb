#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class ShiftScheduleProfileTime < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "ShiftScheduleProfileTime"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for schedules that are applied to surfaces in the model
    schedule_handles = OpenStudio::StringVector.new
    schedule_display_names = OpenStudio::StringVector.new

    #putting space types and names into hash
    schedule_args = model.getScheduleRulesets
    schedule_args_hash = {}
    schedule_args.each do |schedule_arg|
      schedule_args_hash[schedule_arg.name.to_s] = schedule_arg
    end

    #looping through sorted hash of schedules
    schedule_args_hash.sort.map do |key,value|
      #only include if schedule use count > 0
      if value.directUseCount > 0
        schedule_handles << value.handle.to_s
        schedule_display_names << key
      end
    end

    #add building to string vector with air loops
    building = model.getBuilding
    schedule_handles << building.handle.to_s
    schedule_display_names << "*All Ruleset Schedules*"

    #todo - offer entire building as an option vs. just a single schedule.

    #make an argument for schedule
    schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("schedule", schedule_handles, schedule_display_names,true)
    schedule.setDisplayName("Choose a Schedule to Shift the Time For.")
    schedule.setDefaultValue("*All Ruleset Schedules*") #if no schedule is chosen this will run on all air loops
    args << schedule

    #make an argument to add new space true/false
    shift_value = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("shift_value",true)
    shift_value.setDisplayName("Shift Schedule Profiles Forward (24hr, use decimal for sub hour).")
    shift_value.setDefaultValue(1)
    args << shift_value

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
    schedule = runner.getOptionalWorkspaceObjectChoiceValue("schedule",user_arguments,model)
    shift_value = runner.getDoubleArgumentValue("shift_value",user_arguments)

    #check the schedule for reasonableness
    apply_to_all_schedules = false
    if schedule.empty?
      handle = runner.getStringArgumentValue("schedule",user_arguments)
      if handle.empty?
        runner.registerError("No schedule was chosen.")
      else
        runner.registerError("The selected schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not schedule.get.to_ScheduleRuleset.empty?
        schedule = schedule.get.to_ScheduleRuleset.get
      elsif not schedule.get.to_Building.empty?
        apply_to_all_schedules = true
      else
        runner.registerError("Script Error - argument not showing up as schedule.")
        return false
      end
    end  #end of if schedule.empty?    

    #check shift value for reasonableness
    if (shift_value/24) == (shift_value/24).to_i
      runner.registerAsNotApplicable("No schedule shift was requested, the model was not changed.")
    end

    #get schedules for measure
    schedules = []
    if apply_to_all_schedules
      raw_schedules = model.getScheduleRulesets
      raw_schedules.each do |raw_schedule|
        if raw_schedule.directUseCount > 0
          schedules << raw_schedule
        end
      end

    else
      schedules << schedule #only run on a single schedule
    end

    schedules.each do |schedule|

      #rename schedule
      schedule.setName("#{schedule.name} - (shifted #{shift_value} hours)")

      #array of all profiles to change
      profiles = []

      #push default profiles to array
      default_rule = schedule.defaultDaySchedule
      profiles << default_rule

      #push profiles to array
      rules = schedule.scheduleRules
      rules.each do |rule|
        day_sch = rule.daySchedule
        profiles << day_sch
      end

      #add design days to array
      summer_design = schedule.summerDesignDaySchedule
      winter_design = schedule.winterDesignDaySchedule
      profiles << summer_design
      profiles << winter_design

      #reporting initial condition of model
      runner.registerInitialCondition("Schedule #{schedule.name} has #{} profiles including design days.")

      shift_hours = (shift_value).to_i
      shift_minutes = (((shift_value)-(shift_value).to_i)*60).to_i

      #give info messages as I change specific profiles
      runner.registerInfo("Adjusting #{schedule.name}")

      #edit profiles
      profiles.each do |day_sch|
        times = day_sch.times
        values = day_sch.values

        #time objects to use in meausre
        time_0 =  OpenStudio::Time.new(0, 0, 0, 0)
        time_24 =  OpenStudio::Time.new(0, 24, 0, 0)
        shift_time = OpenStudio::Time.new(0, shift_hours, shift_minutes, 0)

        #arrays for values to avoid overlap conflict of times
        new_times = []
        new_values = []

        #create a a pair of times and values for what will be 0 time after adjustment
        new_times << time_24
        if shift_time > time_0
          new_values << day_sch.getValue(time_24 - shift_time)
        else
          new_values << day_sch.getValue(time_0 - shift_time)
        end

        #push times to array
        times.each do |time|
          new_time = time + shift_time

          #adjust wrap around times
          if new_time < time_0
            new_times << new_time + time_24
          elsif new_time > time_24
            new_times << new_time - time_24
          else
            new_times << new_time
          end

        end  #end of times.each do

        #push values to array
        values.each do |value|
          new_values << value
        end #end of values.each do

        #clear values
        day_sch.clearValues

        #make new values
        for i in 0..(new_values.length - 1)
          day_sch.addValue(new_times[i], new_values[i])
        end

      end  #end of profiles.each do

    end #end of schedules.each do

    #reporting final condition of model
    if apply_to_all_schedules
      runner.registerFinalCondition("Shifted time for all schedule profiles.")
    else
      runner.registerFinalCondition("Shifted time for all profiles used by #{schedule.name}.")
    end
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ShiftScheduleProfileTime.new.registerWithApplication