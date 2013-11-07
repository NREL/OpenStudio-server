require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class AdjustTheromstatSetpointsByDegrees_Test < Test::Unit::TestCase

  
  def test_AdjustTheromstatSetpointsByDegrees_fail
     
    # create an instance of the measure
    measure = AdjustTheromstatSetpointsByDegrees.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # make an empty model
    model = OpenStudio::Model::Model.new


    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(3, arguments.size)
    assert_equal("cooling_adjustment", arguments[0].name)
    assert_equal("heating_adjustment", arguments[1].name)
    assert_equal("alter_design_days", arguments[2].name)

    # set argument values to bad values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    cooling_adjustment = arguments[0].clone
    assert(cooling_adjustment.setValue(5000.0))
    argument_map["cooling_adjustment"] = cooling_adjustment
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == "Fail")
  end
  
  def test_AdjustTheromstatSetpointsByDegrees_good__no_design_day

    # create an instance of the measure
    measure = AdjustTheromstatSetpointsByDegrees.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
  
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/ThermostatTestModel.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get    

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(3, arguments.size)
    assert_equal("cooling_adjustment", arguments[0].name)
    assert_equal("heating_adjustment", arguments[1].name)
    assert_equal("alter_design_days", arguments[2].name)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    cooling_adjustment = arguments[0].clone
    assert(cooling_adjustment.setValue(2.0))
    argument_map["cooling_adjustment"] = cooling_adjustment
    heating_adjustment = arguments[1].clone
    assert(heating_adjustment.setValue(-1.0))
    argument_map["heating_adjustment"] = heating_adjustment
    alter_design_days = arguments[2].clone
    assert(alter_design_days.setValue(false))
    argument_map["alter_design_days"] = alter_design_days
    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 5)
    assert(result.info.size == 0)
    
    #save the model
    # output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    # model.save(output_file_path,true)    
    
  end

  def test_AdjustTheromstatSetpointsByDegrees_good_design_day

    # create an instance of the measure
    measure = AdjustTheromstatSetpointsByDegrees.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/ThermostatTestModel.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(3, arguments.size)
    assert_equal("cooling_adjustment", arguments[0].name)
    assert_equal("heating_adjustment", arguments[1].name)
    assert_equal("alter_design_days", arguments[2].name)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    cooling_adjustment = arguments[0].clone
    assert(cooling_adjustment.setValue(2.0))
    argument_map["cooling_adjustment"] = cooling_adjustment
    heating_adjustment = arguments[1].clone
    assert(heating_adjustment.setValue(-1.0))
    argument_map["heating_adjustment"] = heating_adjustment
    alter_design_days = arguments[2].clone
    assert(alter_design_days.setValue(true))
    argument_map["alter_design_days"] = alter_design_days
    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 5)
    assert(result.info.size == 0)

    #save the model
    # output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    # model.save(output_file_path,true)

  end

  def test_AdjustTheromstatSetpointsByDegrees_NoRuleSet

    # create an instance of the measure
    measure = AdjustTheromstatSetpointsByDegrees.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
  
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/seed_model.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get    

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(3, arguments.size)
    assert_equal("cooling_adjustment", arguments[0].name)
    assert_equal("heating_adjustment", arguments[1].name)
    
    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    cooling_adjustment = arguments[0].clone
    assert(cooling_adjustment.setValue(2.0))
    argument_map["cooling_adjustment"] = cooling_adjustment
    heating_adjustment = arguments[1].clone
    assert(heating_adjustment.setValue(-1.0))
    argument_map["heating_adjustment"] = heating_adjustment
    alter_design_days = arguments[2].clone
    assert(alter_design_days.setValue(false))
    argument_map["alter_design_days"] = alter_design_days
    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "NA")
    assert(result.warnings.size == 2)
    assert(result.info.size == 1)
    
    #save the model
    # output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    # model.save(output_file_path,true)    
    
  end    
  
end
