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

class ReduceLightingLoadsByPercentage_Test < Test::Unit::TestCase

  # Test model summary
  # Lighting Power - 2385.06 W
  # Area - 82.80 m^2, 891.25 ft^2
  # Lighting Power Density - 28.805 W/m^2, 2.676 W/ft^2
  # Spaces:
  #   Space 101
  #     Area = 20.70 m^2, 222.81 ft^2
  #     Space Type = Multiple Lights Both LPD different schedules
  #   Space 102
  #     Area = 20.70 m^2, 222.81 ft^2
  #     Space Type = MultipleLights one LPD one Load x5 multiplier Same Schedule
  #   Space 103 (extra light in space diff schedule)
  #     Area = 20.70 m^2, 222.81 ft^2
  #     Lights 5 = 12.593775 W/m^2 (ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Cafe_LightsDef)
  #     Space Type = Single Light LPD
  #       Lights 4 = 11.625023 W/m^2 (ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Kitchen_LightsDef)
  #   Space 104 (extra light in space diff schedule)
  #     Area = 20.70 m^2, 222.81 ft^2
  #     Space Type = Multiple Lights Both LPD different schedules

  def test_DefaultArgs

    # create an instance of the measure
    measure = ReduceLightingLoadsByPercentage.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # refresh arguments
    arguments = measure.arguments(model)

    # fill in argument_map
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    space_type = arguments[0].clone
    argument_map["space_type"] = space_type

    reduction_percent = arguments[1].clone
    argument_map["reduction_percent"] = reduction_percent

    count = 1

    material_and_installation_cost = arguments[count += 1].clone
    argument_map["material_and_installation_cost"] = material_and_installation_cost

    demolition_cost = arguments[count += 1].clone
    argument_map["demolition_cost"] = demolition_cost

    years_until_costs_start = arguments[count += 1].clone
    argument_map["years_until_costs_start"] = years_until_costs_start

    initial_demo_costs = arguments[count += 1].clone
    argument_map["initial_demo_costs"] = initial_demo_costs

    expected_life = arguments[count += 1].clone
    argument_map["expected_life"] = expected_life

    om_cost = arguments[count += 1].clone
    argument_map["om_cost"] = om_cost

    om_frequency = arguments[count += 1].clone
    argument_map["om_frequency"] = om_frequency

    # test the input model
    assert_in_delta(2385.06, model.building.get.lightingPower, 0.1)
    assert_in_delta(82.80, model.building.get.floorArea, 0.1)

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == "Success", show_output(result))

    # test the output model
    assert_in_delta(1669.54, model.building.get.lightingPower, 0.1)
    assert_in_delta(82.80, model.building.get.floorArea, 0.1)

    # test warning messages
    assert((not result.initialCondition.empty?))
    # The model's initial building lighting power was 2385 W, a power density of 2.68 W/ft^2.
    assert_equal("The model's initial building lighting power was 2385 W, a power density of 2.68 W/ft^2.", result.initialCondition.get.logMessage)

    assert((not result.finalCondition.empty?))
    assert_equal("LPD was reduced by 30.00% in selected spaces.  The building now has an overall average of 1.87 W/ft^2.", result.finalCondition.get.logMessage)

    expected_messages = Hash.new
    result.warnings.each do |warning|
      expected_messages.each_key do |message|
        if Regexp.new(message).match(warning.logMessage)
          assert(expected_messages[message] == false, "Message '#{message}' found multiple times")
          expected_messages[message] = true
        end
      end
    end

    expected_messages.each_pair do |message, found|
      assert(found, "Message '#{message}' not found")
    end

  end

  #################################################################################################
  #################################################################################################

  def test_NoReductionNoCost

    # create an instance of the measure
    measure = ReduceLightingLoadsByPercentage.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # refresh arguments
    arguments = measure.arguments(model)

    # fill in argument_map
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    space_type = arguments[0].clone
    argument_map["space_type"] = space_type

    reduction_percent = arguments[1].clone
    assert(reduction_percent.setValue(0))
    argument_map["reduction_percent"] = reduction_percent

    count = 1

    material_and_installation_cost = arguments[count += 1].clone
    assert(material_and_installation_cost.setValue(0))
    argument_map["material_and_installation_cost"] = material_and_installation_cost

    demolition_cost = arguments[count += 1].clone
    argument_map["demolition_cost"] = demolition_cost

    years_until_costs_start = arguments[count += 1].clone
    argument_map["years_until_costs_start"] = years_until_costs_start

    initial_demo_costs = arguments[count += 1].clone
    argument_map["initial_demo_costs"] = initial_demo_costs

    expected_life = arguments[count += 1].clone
    argument_map["expected_life"] = expected_life

    om_cost = arguments[count += 1].clone
    argument_map["om_cost"] = om_cost

    om_frequency = arguments[count += 1].clone
    argument_map["om_frequency"] = om_frequency

    # test the input model
    assert_in_delta(2385.06, model.building.get.lightingPower, 0.1)
    assert_in_delta(82.80, model.building.get.floorArea, 0.1)

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    puts result.value.valueName
    assert(result.value.valueName == "NA", show_output(result))

    # test the output model
    assert_in_delta(2385.06, model.building.get.lightingPower, 0.1)
    assert_in_delta(82.80, model.building.get.floorArea, 0.1)

    # test warning messages
    assert((not result.initialCondition.empty?))
    # The model's initial building lighting power was 2385 W, a power density of 2.68 W/ft^2.
    assert_equal("The model's initial building lighting power was 2385 W, a power density of 2.68 W/ft^2.", result.initialCondition.get.logMessage)

    assert((not result.finalCondition.empty?))
    assert_equal("LPD was reduced by 0.00% in selected spaces.  The building now has an overall average of 2.68 W/ft^2.", result.finalCondition.get.logMessage)

    expected_messages = Hash.new
    result.warnings.each do |warning|
      expected_messages.each_key do |message|
        if Regexp.new(message).match(warning.logMessage)
          assert(expected_messages[message] == false, "Message '#{message}' found multiple times")
          expected_messages[message] = true
        end
      end
    end

    expected_messages.each_pair do |message, found|
      assert(found, "Message '#{message}' not found")
    end

  end

  #################################################################################################
  #################################################################################################

  def test_UncostedExpectedLife

    # create an instance of the measure
    measure = ReduceLightingLoadsByPercentage.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # refresh arguments
    arguments = measure.arguments(model)

    # fill in argument_map
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    space_type = arguments[0].clone
    assert(space_type.setValue("*Entire Building*"))
    argument_map["space_type"] = space_type

    reduction_percent = arguments[1].clone
    assert(reduction_percent.setValue(45.0))
    argument_map["reduction_percent"] = reduction_percent

    count = 1

    material_and_installation_cost = arguments[count += 1].clone
    #puts material_and_installation_cost.displayName
    assert(material_and_installation_cost.setValue(50.0))
    argument_map["material_and_installation_cost"] = material_and_installation_cost

    demolition_cost = arguments[count += 1].clone
    #puts demolition_cost.displayName
    assert(demolition_cost.setValue(18.0))
    argument_map["demolition_cost"] = demolition_cost

    years_until_costs_start = arguments[count += 1].clone
    #puts years_until_costs_start.displayName
    assert(years_until_costs_start.setValue(1))
    argument_map["years_until_costs_start"] = years_until_costs_start

    initial_demo_costs = arguments[count += 1].clone
    #puts initial_demo_costs.displayName
    assert(initial_demo_costs.setValue(true))
    argument_map["initial_demo_costs"] = initial_demo_costs

    expected_life = arguments[count += 1].clone
    #puts expected_life.displayName
    assert(expected_life.setValue(20))
    argument_map["expected_life"] = expected_life

    om_cost = arguments[count += 1].clone
    #puts om_cost.displayName
    assert(om_cost.setValue(20))
    argument_map["om_cost"] = om_cost

    om_frequency = arguments[count += 1].clone
    #puts om_frequency.displayName
    assert(om_frequency.setValue(20))
    argument_map["om_frequency"] = om_frequency

    # test the input model
    assert_in_delta(2385.06, model.building.get.lightingPower, 0.1)
    assert_in_delta(82.80, model.building.get.floorArea, 0.1)

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == "Success", show_output(result))

    # test the output model
    assert_in_delta(1311.782, model.building.get.lightingPower, 0.1)
    assert_in_delta(82.80, model.building.get.floorArea, 0.1)

    # test warning messages
    assert((not result.initialCondition.empty?))
    # The model's initial building lighting power was 2385 W, a power density of 2.68 W/ft^2.
    assert_equal("The model's initial building lighting power was 2385 W, a power density of 2.68 W/ft^2.", result.initialCondition.get.logMessage)

    assert((not result.finalCondition.empty?))
    assert_equal("LPD was reduced by 45.00% in selected spaces.  The building now has an overall average of 1.47 W/ft^2.", result.finalCondition.get.logMessage)

    expected_messages = Hash.new
    result.warnings.each do |warning|
      expected_messages.each_key do |message|
        if Regexp.new(message).match(warning.logMessage)
          assert(expected_messages[message] == false, "Message '#{message}' found multiple times")
          expected_messages[message] = true
        end
      end
    end

    expected_messages.each_pair do |message, found|
      assert(found, "Message '#{message}' not found")
    end

  end

  #################################################################################################
  #################################################################################################

  def test_NewConstructionUncostedSpaceType

    # create an instance of the measure
    measure = ReduceLightingLoadsByPercentage.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # refresh arguments
    arguments = measure.arguments(model)

    # fill in argument_map
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    space_type = arguments[0].clone
    assert(space_type.setValue("Single Light LPD"))
    argument_map["space_type"] = space_type

    reduction_percent = arguments[1].clone
    assert(reduction_percent.setValue(15.0))
    argument_map["reduction_percent"] = reduction_percent

    count = 1

    material_and_installation_cost = arguments[count += 1].clone
    #puts material_and_installation_cost.displayName
    assert(material_and_installation_cost.setValue(50.0))
    argument_map["material_and_installation_cost"] = material_and_installation_cost

    demolition_cost = arguments[count += 1].clone
    #puts demolition_cost.displayName
    assert(demolition_cost.setValue(18.0))
    argument_map["demolition_cost"] = demolition_cost

    years_until_costs_start = arguments[count += 1].clone
    #puts years_until_costs_start.displayName
    assert(years_until_costs_start.setValue(1))
    argument_map["years_until_costs_start"] = years_until_costs_start

    initial_demo_costs = arguments[count += 1].clone
    #puts initial_demo_costs.displayName
    assert(initial_demo_costs.setValue(true))
    argument_map["initial_demo_costs"] = initial_demo_costs

    expected_life = arguments[count += 1].clone
    #puts expected_life.displayName
    assert(expected_life.setValue(20))
    argument_map["expected_life"] = expected_life

    om_cost = arguments[count += 1].clone
    #puts om_cost.displayName
    assert(om_cost.setValue(20))
    argument_map["om_cost"] = om_cost

    om_frequency = arguments[count += 1].clone
    #puts om_frequency.displayName
    assert(om_frequency.setValue(20))
    argument_map["om_frequency"] = om_frequency

    # test the input model
    assert_in_delta(2385.06, model.building.get.lightingPower, 0.1)
    assert_in_delta(82.80, model.building.get.floorArea, 0.1)

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == "Success", show_output(result))

  #     Area = 20.70 m^2, 222.81 ft^2
  #     Lights 5 = 12.593775 W/m^2 (ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Cafe_LightsDef)
  #     Space Type = Single Light LPD
  #     Lights 4 = 11.625023 W/m^2 (ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Kitchen_LightsDef)

    space_103_found = false
    model.getSpaces.each do |space|
      #puts space.name.get
      if space.name.get == "Space 103 (extra light in space diff schedule)"
        space_103_found = true
        assert_equal(1, space.lights.size)
        assert_equal("Lights 5 - 15.0 percent reduction", space.lights[0].name.get)
        assert_equal("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Cafe_LightsDef - 15.0 percent reduction", space.lights[0].definition.name.get)
        assert((not space.lights[0].definition.to_LightsDefinition.get.wattsperSpaceFloorArea.empty?))
        assert_in_delta(12.59*(1-0.15), space.lights[0].definition.to_LightsDefinition.get.wattsperSpaceFloorArea.get, 0.01)

        assert((not space.spaceType.empty?))
        assert_equal(1, space.spaceType.get.lights.size)
        assert_equal("Lights 4 - 15.0 percent reduction", space.spaceType.get.lights[0].name.get)
        assert_equal("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Kitchen_LightsDef - 15.0 percent reduction", space.spaceType.get.lights[0].definition.name.get)
        assert((not space.spaceType.get.lights[0].definition.to_LightsDefinition.get.wattsperSpaceFloorArea.empty?))
        assert_in_delta(11.625*(1-0.15), space.spaceType.get.lights[0].definition.to_LightsDefinition.get.wattsperSpaceFloorArea.get, 0.01)
      end
    end
    assert(space_103_found)

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == "Success", show_output(result))

    #model.save(OpenStudio::Path.new("C:/working/utilities/OpenStudio/measures/instances/ReduceLightingLoadsByPercentage/tests/out.osm"), true)

    # test the output model
    #assert_in_delta(2385.06-0.15*(12.59+11.6250)*20.70, model.building.get.lightingPower, 0.1)
    assert_in_delta(82.80, model.building.get.floorArea, 0.1)

    space_103_found = false
    model.getSpaces.each do |space|
      if space.name.get == "Space 103 (extra light in space diff schedule)"
        space_103_found = true
        assert_equal(1, space.lights.size)
        assert_equal("Lights 5 - 15.0 percent reduction - 15.0 percent reduction", space.lights[0].name.get)
        assert_equal("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Cafe_LightsDef - 15.0 percent reduction - 15.0 percent reduction", space.lights[0].definition.name.get)
        assert((not space.lights[0].definition.to_LightsDefinition.get.wattsperSpaceFloorArea.empty?))
        assert_in_delta(12.59*0.85*0.85, space.lights[0].definition.to_LightsDefinition.get.wattsperSpaceFloorArea.get, 0.01)
        assert_equal(1, space.lights[0].definition.instances.size)

        assert((not space.spaceType.empty?))
        assert_equal(1, space.spaceType.get.lights.size)
        assert_equal("Lights 4 - 15.0 percent reduction - 15.0 percent reduction", space.spaceType.get.lights[0].name.get)
        assert_equal("ASHRAE_189.1-2009_ClimateZone 1-3_LargeHotel_Kitchen_LightsDef - 15.0 percent reduction - 15.0 percent reduction", space.spaceType.get.lights[0].definition.name.get)
        assert((not space.spaceType.get.lights[0].definition.to_LightsDefinition.get.wattsperSpaceFloorArea.empty?))
        assert_in_delta(11.625*0.85*0.85, space.spaceType.get.lights[0].definition.to_LightsDefinition.get.wattsperSpaceFloorArea.get, 0.01)
        assert_equal(1, space.spaceType.get.lights[0].definition.instances.size)
      end
    end
    assert(space_103_found)

    # test warning messages
    assert((not result.initialCondition.empty?))
    #assert_equal("The model's initial building lighting power was 2385 W, a power density of 2.68 W/ft^2.", result.initialCondition.get.logMessage)

    assert((not result.finalCondition.empty?))
    assert("LPD was reduced by 15.00% in selected spaces. The building now has an overall average of 2.64 W/ft^2.", result.finalCondition.get.logMessage)

    expected_messages = Hash.new
    expected_messages[/Expected life entered but no costs are entered, resetting expected life/] = false
    result.warnings.each do |warning|
      expected_messages.each_key do |message|
        if Regexp.new(message).match(warning.logMessage)
          assert(expected_messages[message] == false, "Message '#{message}' found multiple times")
          expected_messages[message] = true
        end
      end
    end

    expected_messages.each_pair do |message, found|
    end

  end

end
