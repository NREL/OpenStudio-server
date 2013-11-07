require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class EnableEconomizerControl_Test < Test::Unit::TestCase
  
  def test_EnableEconomizerControl_single_loop
     
    # create an instance of the measure
    measure = EnableEconomizerControl.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(14, arguments.size)
    count = -1
    assert_equal("object", arguments[count += 1].name)
    assert_equal("economizer_type", arguments[count += 1].name)
    assert_equal("econoMaxDryBulbTemp", arguments[count += 1].name)
    assert_equal("econoMaxEnthalpy", arguments[count += 1].name)
    assert_equal("econoMaxDewpointTemp", arguments[count += 1].name)
    assert_equal("econoMinDryBulbTemp", arguments[count += 1].name)
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

    economizer_type = arguments[count += 1].clone
    assert(economizer_type.setValue("FixedDryBulb"))
    argument_map["economizer_type"] = economizer_type

    econoMaxDryBulbTemp = arguments[count += 1].clone
    assert(econoMaxDryBulbTemp.setValue(72))
    argument_map["econoMaxDryBulbTemp"] = econoMaxDryBulbTemp

    econoMaxEnthalpy = arguments[count += 1].clone
    assert(econoMaxEnthalpy.setValue(26))
    argument_map["econoMaxEnthalpy"] = econoMaxEnthalpy

    econoMaxDewpointTemp = arguments[count += 1].clone
    assert(econoMaxDewpointTemp.setValue(56))
    argument_map["econoMaxDewpointTemp"] = econoMaxDewpointTemp

    econoMinDryBulbTemp = arguments[count += 1].clone
    assert(econoMinDryBulbTemp.setValue(-150))
    argument_map["econoMinDryBulbTemp"] = econoMinDryBulbTemp

    remove_costs = arguments[count += 1].clone
    assert(remove_costs.setValue(false))
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

  #test on all loops

  #test warning values

  #test bad values

  #test model with some economizers on and type set to No Economiser

end
