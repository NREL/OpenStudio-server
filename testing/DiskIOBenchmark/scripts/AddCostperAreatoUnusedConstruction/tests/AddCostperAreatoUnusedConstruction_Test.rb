require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class AddCostPerAreaToUnusedConstruction_Test < Test::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_AddCostPerAreaToUnusedConstruction_fail

    # create an instance of the measure
    measure = AddCostPerAreaToUnusedConstruction.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(9, arguments.size)
    count = -1
    assert_equal("construction", arguments[count += 1].name)
    assert_equal("remove_costs", arguments[count += 1].name)
    assert_equal("material_cost_ip", arguments[count += 1].name)
    assert_equal("demolition_cost_ip", arguments[count += 1].name)
    assert_equal("years_until_costs_start", arguments[count += 1].name)
    assert_equal("demo_cost_initial_const", arguments[count += 1].name)
    assert_equal("expected_life", arguments[count += 1].name)
    assert_equal("om_cost_ip", arguments[count += 1].name)
    assert_equal("om_frequency", arguments[count += 1].name)

    # set argument values to bad values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    construction = arguments[0].clone
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == "Fail") #no construction selected
  end

  def test_AddCostPerAreaToUnusedConstruction_good

    # create an instance of the measure
    measure = AddCostPerAreaToUnusedConstruction.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/0416_NetArea_b.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    construction = arguments[count += 1].clone
    assert(construction.setValue("000 Interior Partition"))
    argument_map["construction"] = construction

    remove_costs = arguments[count += 1].clone
    assert(remove_costs.setValue(true))
    argument_map["remove_costs"] = remove_costs

    material_cost_ip = arguments[count += 1].clone
    assert(material_cost_ip.setValue(5.0))
    argument_map["material_cost_ip"] = material_cost_ip

    demolition_cost_ip = arguments[count += 1].clone
    assert(demolition_cost_ip.setValue(1.0))
    argument_map["demolition_cost_ip"] = demolition_cost_ip

    years_until_costs_start = arguments[count += 1].clone
    assert(years_until_costs_start.setValue(0))
    argument_map["years_until_costs_start"] = years_until_costs_start

    demo_cost_initial_const = arguments[count += 1].clone
    assert(demo_cost_initial_const.setValue(false))
    argument_map["demo_cost_initial_const"] = demo_cost_initial_const

    expected_life = arguments[count += 1].clone
    assert(expected_life.setValue(20))
    argument_map["expected_life"] = expected_life

    om_cost_ip = arguments[count += 1].clone
    assert(om_cost_ip.setValue(0.25))
    argument_map["om_cost_ip"] = om_cost_ip

    om_frequency = arguments[count += 1].clone
    assert(om_frequency.setValue(1))
    argument_map["om_frequency"] = om_frequency

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 0)
    #assert(result.info.size == 5)

  end

end
