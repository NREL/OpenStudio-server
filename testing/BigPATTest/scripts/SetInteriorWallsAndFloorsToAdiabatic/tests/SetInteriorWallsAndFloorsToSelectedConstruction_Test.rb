require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class SetInteriorWallsAndFloorsToAdiabatic_Test < Test::Unit::TestCase

  
  def test_SetInteriorWallsAndFloorsToAdiabatic
     
    # create an instance of the measure
    measure = SetInteriorWallsAndFloorsToAdiabatic.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
    assert_equal("construction", arguments[0].name)
    assert((not arguments[0].hasDefaultValue))
       
    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    construction = arguments[0].clone
    assert(construction.setValue("Air Wall"))
    argument_map["construction"] = construction
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
    assert(result.info.size == 0)

  end  

end
