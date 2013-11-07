######################################################################
#  Copyright (c) 2008-2013, Alliance for Sustainable Energy.  
#  All rights reserved.
#  
#  This library is free software you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation either
#  version 2.1 of the License, or (at your option) any later version.
#  
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#  
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class ReduceNightTimeLightingLoads_Test < Test::Unit::TestCase
  
  # def setup
  # end

  # def teardown
  # end
  
  def test_ReduceNightTimeLightingLoads_a
     
    # create an instance of the measure
    measure = ReduceNightTimeLightingLoads.new
    
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
    assert_equal(16, arguments.size)
    assert_equal("lights_def", arguments[0].name)
    
    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    lights_def = arguments[0].clone
    assert(lights_def.setValue("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Cafe_LightsDef"))
    argument_map["lights_def"] = lights_def
    fraction_value = arguments[1].clone
    assert(fraction_value.setValue(0.1))
    argument_map["fraction_value"] = fraction_value

    apply_weekday = arguments[2].clone
    assert(apply_weekday.setValue("true"))
    argument_map["apply_weekday"] = apply_weekday
    start_weekday = arguments[3].clone
    assert(start_weekday.setValue(18.0))
    argument_map["start_weekday"] = start_weekday
    end_weekday = arguments[4].clone
    assert(end_weekday.setValue(9.0))
    argument_map["end_weekday"] = end_weekday

    apply_saturday = arguments[5].clone
    assert(apply_saturday.setValue("true"))
    argument_map["apply_saturday"] = apply_saturday
    start_saturday = arguments[6].clone
    assert(start_saturday.setValue(18.0))
    argument_map["start_saturday"] = start_saturday
    end_saturday = arguments[7].clone
    assert(end_saturday.setValue(9.0))
    argument_map["end_saturday"] = end_saturday

    apply_sunday = arguments[8].clone
    assert(apply_sunday.setValue("false"))
    argument_map["apply_sunday"] = apply_sunday
    start_sunday = arguments[9].clone
    assert(start_sunday.setValue(18.0))
    argument_map["start_sunday"] = start_sunday
    end_sunday = arguments[10].clone
    assert(end_sunday.setValue(9.0))
    argument_map["end_sunday"] = end_sunday

    material_cost = arguments[11].clone
    assert(material_cost.setValue(100.0))
    argument_map["material_cost"] = material_cost

    years_until_costs_start = arguments[12].clone
    assert(years_until_costs_start.setValue(0))
    argument_map["years_until_costs_start"] = years_until_costs_start

    expected_life = arguments[13].clone
    assert(expected_life.setValue(50))
    argument_map["expected_life"] = expected_life

    om_cost = arguments[14].clone
    assert(om_cost.setValue(1))
    argument_map["om_cost"] = om_cost

    om_frequency = arguments[15].clone
    assert(om_frequency.setValue(5))
    argument_map["om_frequency"] = om_frequency

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 2)
    assert(result.info.size == 1)

  end

  def test_ReduceNightTimeLightingLoads_b

    # create an instance of the measure
    measure = ReduceNightTimeLightingLoads.new

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
    assert_equal(16, arguments.size)
    assert_equal("lights_def", arguments[0].name)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    lights_def = arguments[0].clone
    assert(lights_def.setValue("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Kitchen_LightsDef"))
    argument_map["lights_def"] = lights_def
    fraction_value = arguments[1].clone
    assert(fraction_value.setValue(0.1))
    argument_map["fraction_value"] = fraction_value

    apply_weekday = arguments[2].clone
    assert(apply_weekday.setValue("true"))
    argument_map["apply_weekday"] = apply_weekday
    start_weekday = arguments[3].clone
    assert(start_weekday.setValue(18.0))
    argument_map["start_weekday"] = start_weekday
    end_weekday = arguments[4].clone
    assert(end_weekday.setValue(9.0))
    argument_map["end_weekday"] = end_weekday

    apply_saturday = arguments[5].clone
    assert(apply_saturday.setValue("true"))
    argument_map["apply_saturday"] = apply_saturday
    start_saturday = arguments[6].clone
    assert(start_saturday.setValue(18.0))
    argument_map["start_saturday"] = start_saturday
    end_saturday = arguments[7].clone
    assert(end_saturday.setValue(9.0))
    argument_map["end_saturday"] = end_saturday

    apply_sunday = arguments[8].clone
    assert(apply_sunday.setValue("false"))
    argument_map["apply_sunday"] = apply_sunday
    start_sunday = arguments[9].clone
    assert(start_sunday.setValue(18.0))
    argument_map["start_sunday"] = start_sunday
    end_sunday = arguments[10].clone
    assert(end_sunday.setValue(9.0))
    argument_map["end_sunday"] = end_sunday

    material_cost = arguments[11].clone
    assert(material_cost.setValue(100.0))
    argument_map["material_cost"] = material_cost

    years_until_costs_start = arguments[12].clone
    assert(years_until_costs_start.setValue(0))
    argument_map["years_until_costs_start"] = years_until_costs_start

    expected_life = arguments[13].clone
    assert(expected_life.setValue(50))
    argument_map["expected_life"] = expected_life

    om_cost = arguments[14].clone
    assert(om_cost.setValue(1))
    argument_map["om_cost"] = om_cost

    om_frequency = arguments[15].clone
    assert(om_frequency.setValue(5))
    argument_map["om_frequency"] = om_frequency

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 1)
    assert(result.info.size == 2)    
    
    #save the model
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)

    
  end
  

end


