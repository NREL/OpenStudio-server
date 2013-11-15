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

class AddDaylightSensors_Test < Test::Unit::TestCase
  
  # def setup
  # end

  # def teardown
  # end
  
  def test_AddDaylightSensors
     
    # create an instance of the measure
    measure = AddDaylightSensors.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # make an empty model
    model = OpenStudio::Model::Model.new
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(13, arguments.size)
    assert_equal("space_type", arguments[0].name)
    assert((not arguments[0].hasDefaultValue))
       
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/ModelForDaylightSensors.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    space_type = arguments[count += 1].clone
    assert(space_type.setValue("ASHRAE_189.1-2009_ClimateZone 4-8_LargeHotel_GuestRoom"))
    argument_map["space_type"] = space_type

    setpoint = arguments[count += 1].clone
    assert(setpoint.setValue(50.0))
    argument_map["setpoint"] = setpoint

    control_type = arguments[count += 1].clone
    assert(control_type.setValue("Continuous/Off"))
    argument_map["control_type"] = control_type

    min_power_fraction = arguments[count += 1].clone
    assert(min_power_fraction.setValue(0.3))
    argument_map["min_power_fraction"] = min_power_fraction

    min_light_fraction = arguments[count += 1].clone
    assert(min_light_fraction.setValue(0.2))
    argument_map["min_light_fraction"] = min_light_fraction

    height = arguments[count += 1].clone
    assert(height.setValue(30.0))
    argument_map["height"] = height

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
    assert(result.warnings.size == 8)
    assert(result.info.size == 1)
    
    #save the model
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)

  end
  

end


