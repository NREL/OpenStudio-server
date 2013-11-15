require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class SwapLightsDefinition_Test < Test::Unit::TestCase

  def test_SwapLightsDefinition_fail

    # create an instance of the measure
    measure = SwapLightsDefinition.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(3, arguments.size)
    count = -1
    assert_equal("old_lights_def", arguments[count += 1].name)
    assert_equal("new_lights_def", arguments[count += 1].name)
    assert_equal("demo_cost_initial_const", arguments[count += 1].name)
    # set argument values to bad values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == "Fail")
  end

  def test_SwapLightsDefinition_good_UnusedLight

    #code below provides more detailed logging
    #OpenStudio::Logger.instance.standardOutLogger.enable
    #OpenStudio::Logger.instance.standardOutLogger.setLogLevel(-1)

    # create an instance of the measure
    measure = SwapLightsDefinition.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    old_lights_def = arguments[count += 1].clone
    assert(old_lights_def.setValue("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Banquet_LightsDef"))
    argument_map["old_lights_def"] = old_lights_def

    new_lights_def = arguments[count += 1].clone
    assert(new_lights_def.setValue("ASHRAE 189.1-2009 ClimateZone 4-8 MediumOffice LightsDef"))
    argument_map["new_lights_def"] = new_lights_def    
    
    demo_cost_initial_const = arguments[count += 1].clone
    assert(demo_cost_initial_const.setValue(false))
    argument_map["demo_cost_initial_const"] = demo_cost_initial_const

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
    assert(result.info.size == 1)

  end

  def test_SwapLightsDefinition_good_UsedLight

    # create an instance of the measure
    measure = SwapLightsDefinition.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    old_lights_def = arguments[count += 1].clone
    assert(old_lights_def.setValue("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Banquet_LightsDef"))
    argument_map["old_lights_def"] = old_lights_def

    new_lights_def = arguments[count += 1].clone
    assert(new_lights_def.setValue("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Kitchen_LightsDef"))
    argument_map["new_lights_def"] = new_lights_def

    demo_cost_initial_const = arguments[count += 1].clone
    assert(demo_cost_initial_const.setValue(false))
    argument_map["demo_cost_initial_const"] = demo_cost_initial_const

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
    assert(result.info.size == 1)

    #save the model
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)

  end

  def test_SwapLightsDefinition_warning_calc_method_mismatch

    # create an instance of the measure
    measure = SwapLightsDefinition.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    old_lights_def = arguments[count += 1].clone
    assert(old_lights_def.setValue("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Banquet_LightsDef"))
    argument_map["old_lights_def"] = old_lights_def

    new_lights_def = arguments[count += 1].clone
    assert(new_lights_def.setValue("100W light"))
    argument_map["new_lights_def"] = new_lights_def

    demo_cost_initial_const = arguments[count += 1].clone
    assert(demo_cost_initial_const.setValue(false))
    argument_map["demo_cost_initial_const"] = demo_cost_initial_const

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 1)
    assert(result.info.size == 1)

    #save the model
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)

  end

  def test_SwapLightsDefinition_good_UnusedLight_Costed

    #code below provides more detailed logging
    #OpenStudio::Logger.instance.standardOutLogger.enable
    #OpenStudio::Logger.instance.standardOutLogger.setLogLevel(-1)

    # create an instance of the measure
    measure = SwapLightsDefinition.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01_costed.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    old_lights_def = arguments[count += 1].clone
    assert(old_lights_def.setValue("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Banquet_LightsDef"))
    argument_map["old_lights_def"] = old_lights_def

    new_lights_def = arguments[count += 1].clone
    assert(new_lights_def.setValue("ASHRAE 189.1-2009 ClimateZone 4-8 MediumOffice LightsDef"))
    argument_map["new_lights_def"] = new_lights_def

    demo_cost_initial_const = arguments[count += 1].clone
    assert(demo_cost_initial_const.setValue(true))
    argument_map["demo_cost_initial_const"] = demo_cost_initial_const

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
    assert(result.info.size == 2)

  end
end
