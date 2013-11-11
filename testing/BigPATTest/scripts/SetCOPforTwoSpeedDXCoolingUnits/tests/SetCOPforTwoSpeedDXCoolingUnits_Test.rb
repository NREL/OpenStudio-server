require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class SetCOPforTwoSpeedDXCoolingUnits_Test < Test::Unit::TestCase
  
  def test_SetCOPforTwoSpeedDXCoolingUnits_single_loop
     
    # create an instance of the measure
    measure = SetCOPforTwoSpeedDXCoolingUnits.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(11, arguments.size)
    count = -1
    assert_equal("object", arguments[count += 1].name)
    assert_equal("cop_high", arguments[count += 1].name)
    assert_equal("cop_low", arguments[count += 1].name)
    assert_equal("remove_costs", arguments[count += 1].name)
    assert_equal("material_cost", arguments[count += 1].name)
    assert_equal("demolition_cost", arguments[count += 1].name)
    assert_equal("years_until_costs_start", arguments[count += 1].name)
    assert_equal("demo_cost_initial_const", arguments[count += 1].name)
    assert_equal("expected_life", arguments[count += 1].name)
    assert_equal("om_cost", arguments[count += 1].name)
    assert_equal("om_frequency", arguments[count += 1].name)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/0320_ModelWithHVAC_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    object = arguments[count += 1].clone
    assert(object.setValue("Packaged Rooftop VAV with Reheat"))
    argument_map["object"] = object

    cop_high = arguments[count += 1].clone
    assert(cop_high.setValue(2.0))
    argument_map["cop_high"] = cop_high

    cop_low = arguments[count += 1].clone
    assert(cop_low.setValue("4.0"))
    argument_map["cop_low"] = cop_low

    remove_costs = arguments[count += 1].clone
    assert(remove_costs.setValue(true))
    argument_map["remove_costs"] = remove_costs

    material_cost = arguments[count += 1].clone
    assert(material_cost.setValue(5.0))
    argument_map["material_cost"] = material_cost

    demolition_cost = arguments[count += 1].clone
    assert(demolition_cost.setValue(1.0))
    argument_map["demolition_cost"] = demolition_cost

    years_until_costs_start = arguments[count += 1].clone
    assert(years_until_costs_start.setValue(0))
    argument_map["years_until_costs_start"] = years_until_costs_start

    demo_cost_initial_const = arguments[count += 1].clone
    assert(demo_cost_initial_const.setValue(false))
    argument_map["demo_cost_initial_const"] = demo_cost_initial_const

    expected_life = arguments[count += 1].clone
    assert(expected_life.setValue(20))
    argument_map["expected_life"] = expected_life

    om_cost = arguments[count += 1].clone
    assert(om_cost.setValue(0.25))
    argument_map["om_cost"] = om_cost

    om_frequency = arguments[count += 1].clone
    assert(om_frequency.setValue(1))
    argument_map["om_frequency"] = om_frequency

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 2)
    #assert(result.info.size == 1)
    
  end

  def test_SetCOPforTwoSpeedDXCoolingUnits_all_loop

    # create an instance of the measure
    measure = SetCOPforTwoSpeedDXCoolingUnits.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(11, arguments.size)
    count = -1
    assert_equal("object", arguments[count += 1].name)
    assert_equal("cop_high", arguments[count += 1].name)
    assert_equal("cop_low", arguments[count += 1].name)
    assert_equal("remove_costs", arguments[count += 1].name)
    assert_equal("material_cost", arguments[count += 1].name)
    assert_equal("demolition_cost", arguments[count += 1].name)
    assert_equal("years_until_costs_start", arguments[count += 1].name)
    assert_equal("demo_cost_initial_const", arguments[count += 1].name)
    assert_equal("expected_life", arguments[count += 1].name)
    assert_equal("om_cost", arguments[count += 1].name)
    assert_equal("om_frequency", arguments[count += 1].name)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/0320_ModelWithHVAC_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    object = arguments[count += 1].clone
    assert(object.setValue("*All Air Loops*"))
    argument_map["object"] = object

    cop_high = arguments[count += 1].clone
    assert(cop_high.setValue(2.0))
    argument_map["cop_high"] = cop_high

    cop_low = arguments[count += 1].clone
    assert(cop_low.setValue("4.0"))
    argument_map["cop_low"] = cop_low

    remove_costs = arguments[count += 1].clone
    assert(remove_costs.setValue(true))
    argument_map["remove_costs"] = remove_costs

    material_cost = arguments[count += 1].clone
    assert(material_cost.setValue(5.0))
    argument_map["material_cost"] = material_cost

    demolition_cost = arguments[count += 1].clone
    assert(demolition_cost.setValue(1.0))
    argument_map["demolition_cost"] = demolition_cost

    years_until_costs_start = arguments[count += 1].clone
    assert(years_until_costs_start.setValue(0))
    argument_map["years_until_costs_start"] = years_until_costs_start

    demo_cost_initial_const = arguments[count += 1].clone
    assert(demo_cost_initial_const.setValue(false))
    argument_map["demo_cost_initial_const"] = demo_cost_initial_const

    expected_life = arguments[count += 1].clone
    assert(expected_life.setValue(20))
    argument_map["expected_life"] = expected_life

    om_cost = arguments[count += 1].clone
    assert(om_cost.setValue(0.25))
    argument_map["om_cost"] = om_cost

    om_frequency = arguments[count += 1].clone
    assert(om_frequency.setValue(1))
    argument_map["om_frequency"] = om_frequency

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 2)
    #assert(result.info.size == 1)

  end

end
