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

  class AddExteriorLights_Test < Test::Unit::TestCase

    def test_AddExteriorLights
     
    # create an instance of the measure
    measure = AddExteriorLights.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # make an empty model
    model = OpenStudio::Model::Model.new
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(10, arguments.size)

    count = -1

    assert_equal("ext_lighting_level", arguments[count += 1].name)
    assert_equal("end_use_subcategory", arguments[count += 1].name)
    assert_equal("remove_existing_ext_lights", arguments[count += 1].name)
    assert_equal("material_cost", arguments[count += 1].name)
    assert_equal("demolition_cost", arguments[count += 1].name)
    assert_equal("years_until_costs_start", arguments[count += 1].name)
    assert_equal("demo_cost_initial_const", arguments[count += 1].name)
    assert_equal("expected_life", arguments[count += 1].name)
    assert_equal("om_cost", arguments[count += 1].name)
    assert_equal("om_frequency", arguments[count += 1].name)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/RefBldgMediumOfficeNew2004_Chicago_a.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    ext_lighting_level = arguments[count += 1].clone
    assert(ext_lighting_level.setValue(20.0))
    argument_map["ext_lighting_level"] = ext_lighting_level

    end_use_subcategory = arguments[count += 1].clone
    assert(end_use_subcategory.setValue("My Custom End Use Name"))
    argument_map["end_use_subcategory"] = end_use_subcategory

    remove_existing_ext_lights = arguments[count += 1].clone
    assert(remove_existing_ext_lights.setValue("true"))
    argument_map["remove_existing_ext_lights"] = remove_existing_ext_lights

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
    assert(result.info.size == 3)

    #save the model
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)

  end
  

end