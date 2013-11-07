require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class ShiftScheduleProfileTime_Test < Test::Unit::TestCase

  def test_ShiftScheduleProfileTime_a
     
    # create an instance of the measure
    measure = ShiftScheduleProfileTime.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/3Story2Space.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    schedule = arguments[0].clone
    assert(schedule.setValue("Medium Office Bldg Occ"))
    argument_map["schedule"] = schedule

    shift_value = arguments[1].clone
    assert(shift_value.setValue(1.5))
    argument_map["shift_value"] = shift_value

    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
    #assert(result.info.size == 5)

    #save the model
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)
    
  end

  def test_ShiftScheduleProfileTime_b

    # create an instance of the measure
    measure = ShiftScheduleProfileTime.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/3Story2Space.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    schedule = arguments[0].clone
    assert(schedule.setValue("Medium Office Bldg Occ"))
    argument_map["schedule"] = schedule

    shift_value = arguments[1].clone
    assert(shift_value.setValue(-6.0))
    argument_map["shift_value"] = shift_value

    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
    #assert(result.info.size == 5)

    #save the model
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)

  end

  def test_ShiftScheduleProfileTime_all_schedules

    # create an instance of the measure
    measure = ShiftScheduleProfileTime.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/3Story2Space.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    schedule = arguments[0].clone
    assert(schedule.setValue("*All Ruleset Schedules*"))
    argument_map["schedule"] = schedule

    shift_value = arguments[1].clone
    assert(shift_value.setValue(-6.0))
    argument_map["shift_value"] = shift_value

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 0)
    #assert(result.info.size == 5)

    #save the model
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)

  end

  def test_ShiftScheduleProfileTime_NA

    # create an instance of the measure
    measure = ShiftScheduleProfileTime.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/3Story2Space.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    schedule = arguments[0].clone
    assert(schedule.setValue("Medium Office Bldg Occ"))
    argument_map["schedule"] = schedule

    shift_value = arguments[1].clone
    assert(shift_value.setValue(24))
    argument_map["shift_value"] = shift_value

    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "NA")

    #save the model
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)

  end

end
