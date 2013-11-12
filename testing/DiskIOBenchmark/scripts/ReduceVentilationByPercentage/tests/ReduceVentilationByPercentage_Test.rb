require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class ReduceVentilationByPercentage_Test < Test::Unit::TestCase

  def test_ReduceVentilationByPercentage_01_BadInputs

    # create an instance of the measure
    measure = ReduceVentilationByPercentage.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(2, arguments.size)

    # fill in argument_map
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    space_type = arguments[count += 1].clone
    assert(space_type.setValue("*Entire Building*"))
    argument_map["space_type"] = space_type

    design_spec_outdoor_air_reduction_percent = arguments[count += 1].clone
    assert(design_spec_outdoor_air_reduction_percent.setValue(200.0))
    argument_map["design_spec_outdoor_air_reduction_percent"] = design_spec_outdoor_air_reduction_percent

    measure.run(model, runner, argument_map)
    result = runner.result
    puts "test_ReduceVentilationByPercentage_01_BadInputs"
    show_output(result)
    assert(result.value.valueName == "Fail")

  end

  #################################################################################################
  #################################################################################################

  def test_ReduceVentilationByPercentage_02_HighInputs

    # create an instance of the measure
    measure = ReduceVentilationByPercentage.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # re-load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # refresh arguments
    arguments = measure.arguments(model)

    # set argument values to highish values and run the measure on empty model
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    space_type = arguments[count += 1].clone
    assert(space_type.setValue("*Entire Building*"))
    argument_map["space_type"] = space_type

    design_spec_outdoor_air_reduction_percent = arguments[count += 1].clone
    assert(design_spec_outdoor_air_reduction_percent.setValue(95.0))
    argument_map["design_spec_outdoor_air_reduction_percent"] = design_spec_outdoor_air_reduction_percent

    measure.run(model, runner, argument_map)
    result = runner.result
    puts "test_ReduceVentilationByPercentage_02_HighInputs"
    show_output(result)
    assert(result.value.valueName == "Success")
    # assert(result.info.size == 1)
    # assert(result.warnings.size == 1)

  end

  #################################################################################################
  #################################################################################################

  def test_ReduceVentilationByPercentage_04_SpaceTypeNoCosts

    # create an instance of the measure
    measure = ReduceVentilationByPercentage.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # re-load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # refresh arguments
    arguments = measure.arguments(model)

    # set argument values to highish values and run the measure on empty model
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    space_type = arguments[count += 1].clone
    assert(space_type.setValue("MultipleLights one LPD one Load x5 multiplier Same Schedule"))
    argument_map["space_type"] = space_type

    design_spec_outdoor_air_reduction_percent = arguments[count += 1].clone
    assert(design_spec_outdoor_air_reduction_percent.setValue(25.0))
    argument_map["design_spec_outdoor_air_reduction_percent"] = design_spec_outdoor_air_reduction_percent

    measure.run(model, runner, argument_map)
    result = runner.result
    puts "test_ReduceVentilationByPercentage_04_SpaceTypeNoCosts"
    show_output(result)
    assert(result.value.valueName == "Success")
    # assert(result.info.size == 0)
    # assert(result.warnings.size == 0)

  end

  #################################################################################################
  #################################################################################################

  def test_ReduceVentilationByPercentage_05_SharedResource

    # create an instance of the measure
    measure = ReduceVentilationByPercentage.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # re-load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SpaceTypesShareDesignSpecOutdoorAir.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # refresh arguments
    arguments = measure.arguments(model)

    # set argument values to highish values and run the measure on empty model
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    space_type = arguments[count += 1].clone
    assert(space_type.setValue("*Entire Building*"))
    argument_map["space_type"] = space_type

    design_spec_outdoor_air_reduction_percent = arguments[count += 1].clone
    assert(design_spec_outdoor_air_reduction_percent.setValue(25.0))
    argument_map["design_spec_outdoor_air_reduction_percent"] = design_spec_outdoor_air_reduction_percent

    measure.run(model, runner, argument_map)
    result = runner.result
    puts "test_ReduceVentilationByPercentage_04_SpaceTypeNoCosts"
    show_output(result)
    assert(result.value.valueName == "Success")
    # assert(result.info.size == 0)
    # assert(result.warnings.size == 0)

  end


end
