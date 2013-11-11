require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class AddCostToSupplySideHVACComponentByAirLoop_Test < Test::Unit::TestCase
  
  # def setup
  # end

  # def teardown
  # end
  
  def test_AddCostToSupplySideHVACComponentByAirLoop_fail
     
    # create an instance of the measure
    measure = AddCostToSupplySideHVACComponentByAirLoop.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # make an empty model
    model = OpenStudio::Model::Model.new
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(10, arguments.size)
    count = -1
    assert_equal("hvac_comp_type", arguments[count += 1].name)
    assert_equal("object", arguments[count += 1].name)
    assert_equal("remove_costs", arguments[count += 1].name)
    assert_equal("material_cost", arguments[count += 1].name)
    assert_equal("demolition_cost", arguments[count += 1].name)
    assert_equal("years_until_costs_start", arguments[count += 1].name)
    assert_equal("demo_cost_initial_const", arguments[count += 1].name)
    assert_equal("expected_life", arguments[count += 1].name)
    assert_equal("om_cost", arguments[count += 1].name)
    assert_equal("om_frequency", arguments[count += 1].name)

    # set argument values to bad values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    object = arguments[0].clone
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == "Fail") #no object selected
  end

  def test_AddCostToSupplySideHVACComponentByAirLoop_good

    # create an instance of the measure
    measure = AddCostToSupplySideHVACComponentByAirLoop.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
       
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/HVACComponentBasic.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    hvac_comp_type = arguments[count += 1].clone
    assert(hvac_comp_type.setValue("CoilCoolingDXTwoSpeed"))
    argument_map["hvac_comp_type"] = hvac_comp_type

    object = arguments[count += 1].clone
    assert(object.setValue("Packaged Rooftop VAV with PFP Boxes and Reheat"))
    argument_map["object"] = object

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
    assert(result.warnings.size == 0)
    assert(result.info.size == 0)
    
  end

  def test_AddCostToSupplySideHVACComponentByAirLoop_all_air_loops

    # create an instance of the measure
    measure = AddCostToSupplySideHVACComponentByAirLoop.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/HVACComponentBasic.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    hvac_comp_type = arguments[count += 1].clone
    assert(hvac_comp_type.setValue("CoilHeatingElectric"))
    argument_map["hvac_comp_type"] = hvac_comp_type

    object = arguments[count += 1].clone
    assert(object.setValue("*All Air Loops*"))
    argument_map["object"] = object

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
    #assert(result.warnings.size == 0)
    #assert(result.info.size == 0)

  end

end
