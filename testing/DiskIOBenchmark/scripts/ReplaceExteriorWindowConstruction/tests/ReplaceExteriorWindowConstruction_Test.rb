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

class ReplaceExteriorWindowConstruction_Test < Test::Unit::TestCase
  
  # def setup
  # end

  # def teardown
  # end
  
  def test_ReplaceExteriorWindowConstruction
     
    # create an instance of the measure
    measure = ReplaceExteriorWindowConstruction.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # make an empty model
    model = OpenStudio::Model::Model.new
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(11, arguments.size)
    assert_equal("construction", arguments[0].name)
    assert((not arguments[0].hasDefaultValue))

    # set argument values to bad values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    construction = arguments[0].clone
    assert((not construction.setValue("000_Exterior Window")))
    argument_map["construction"] = construction
    measure.run(model, runner, argument_map)
    result = runner.result
       
    assert(result.value.valueName == "Fail")

  end


def test_ReplaceExteriorWindowConstruction_new_construction_FullyCosted
     
    # create an instance of the measure
    measure = ReplaceExteriorWindowConstruction.new
    
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
    assert_equal("construction", arguments[0].name)
    assert((not arguments[0].hasDefaultValue))
    
    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    construction = arguments[count += 1].clone
    assert(construction.setValue("000_Exterior Window"))
    argument_map["construction"] = construction

    change_fixed_windows = arguments[count += 1].clone
    assert(change_fixed_windows.setValue(true))
    argument_map["change_fixed_windows"] = change_fixed_windows

    change_operable_windows = arguments[count += 1].clone
    assert(change_operable_windows.setValue(false))
    argument_map["change_operable_windows"] = change_operable_windows

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
    
  end

  def test_ReplaceExteriorWindowConstruction_retrofit_FullyCosted
     
    # create an instance of the measure
    measure = ReplaceExteriorWindowConstruction.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01Costed.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(11, arguments.size)
    assert_equal("construction", arguments[0].name)
    assert((not arguments[0].hasDefaultValue))
    
    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    construction = arguments[count += 1].clone
    assert(construction.setValue("000_Exterior Window"))
    argument_map["construction"] = construction

    change_fixed_windows = arguments[count += 1].clone
    assert(change_fixed_windows.setValue(true))
    argument_map["change_fixed_windows"] = change_fixed_windows

    change_operable_windows = arguments[count += 1].clone
    assert(change_operable_windows.setValue(false))
    argument_map["change_operable_windows"] = change_operable_windows

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
    assert(years_until_costs_start.setValue(3))
    argument_map["years_until_costs_start"] = years_until_costs_start

    demo_cost_initial_const = arguments[count += 1].clone
    assert(demo_cost_initial_const.setValue(true))
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
    
  end  

  def test_ReplaceExteriorWindowConstruction_retrofit_MinimalCost
     
    # create an instance of the measure
    measure = ReplaceExteriorWindowConstruction.new
    
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
    assert_equal(11, arguments.size)
    assert_equal("construction", arguments[0].name)
    assert((not arguments[0].hasDefaultValue))
    
    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    construction = arguments[count += 1].clone
    assert(construction.setValue("000_Exterior Window"))
    argument_map["construction"] = construction

    change_fixed_windows = arguments[count += 1].clone
    assert(change_fixed_windows.setValue(true))
    argument_map["change_fixed_windows"] = change_fixed_windows

    change_operable_windows = arguments[count += 1].clone
    assert(change_operable_windows.setValue(false))
    argument_map["change_operable_windows"] = change_operable_windows

    remove_costs = arguments[count += 1].clone
    assert(remove_costs.setValue(true))
    argument_map["remove_costs"] = remove_costs

    material_cost_ip = arguments[count += 1].clone
    assert(material_cost_ip.setValue(5.0))
    argument_map["material_cost_ip"] = material_cost_ip

    demolition_cost_ip = arguments[count += 1].clone
    assert(demolition_cost_ip.setValue(0))
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
    assert(om_cost_ip.setValue(0))
    argument_map["om_cost_ip"] = om_cost_ip

    om_frequency = arguments[count += 1].clone
    assert(om_frequency.setValue(1))
    argument_map["om_frequency"] = om_frequency
    
    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "Success")
    
  end    
  
  def test_ReplaceExteriorWindowConstruction_retrofit_NoCost
     
    # create an instance of the measure
    measure = ReplaceExteriorWindowConstruction.new
    
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
    assert_equal(11, arguments.size)
    assert_equal("construction", arguments[0].name)
    assert((not arguments[0].hasDefaultValue))
    
    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    construction = arguments[count += 1].clone
    assert(construction.setValue("000_Exterior Window"))
    argument_map["construction"] = construction

    change_fixed_windows = arguments[count += 1].clone
    assert(change_fixed_windows.setValue(true))
    argument_map["change_fixed_windows"] = change_fixed_windows

    change_operable_windows = arguments[count += 1].clone
    assert(change_operable_windows.setValue(false))
    argument_map["change_operable_windows"] = change_operable_windows

    remove_costs = arguments[count += 1].clone
    assert(remove_costs.setValue(true))
    argument_map["remove_costs"] = remove_costs

    material_cost_ip = arguments[count += 1].clone
    assert(material_cost_ip.setValue(0))
    argument_map["material_cost_ip"] = material_cost_ip

    demolition_cost_ip = arguments[count += 1].clone
    assert(demolition_cost_ip.setValue(0))
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
    assert(om_cost_ip.setValue(0))
    argument_map["om_cost_ip"] = om_cost_ip

    om_frequency = arguments[count += 1].clone
    assert(om_frequency.setValue(1))
    argument_map["om_frequency"] = om_frequency
    
    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "Success")
    
  end

  def test_ReplaceExteriorWindowConstruction_ReverseTranslatedModel

    # create an instance of the measure
    measure = ReplaceExteriorWindowConstruction.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/ReverseTranslatedModel.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(11, arguments.size)
    assert_equal("construction", arguments[0].name)
    assert((not arguments[0].hasDefaultValue))

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    construction = arguments[count += 1].clone
    assert(construction.setValue("Window Non-res Fixed"))
    argument_map["construction"] = construction

    change_fixed_windows = arguments[count += 1].clone
    assert(change_fixed_windows.setValue(true))
    argument_map["change_fixed_windows"] = change_fixed_windows

    change_operable_windows = arguments[count += 1].clone
    assert(change_operable_windows.setValue(false))
    argument_map["change_operable_windows"] = change_operable_windows

    remove_costs = arguments[count += 1].clone
    assert(remove_costs.setValue(true))
    argument_map["remove_costs"] = remove_costs

    material_cost_ip = arguments[count += 1].clone
    assert(material_cost_ip.setValue(0))
    argument_map["material_cost_ip"] = material_cost_ip

    demolition_cost_ip = arguments[count += 1].clone
    assert(demolition_cost_ip.setValue(0))
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
    assert(om_cost_ip.setValue(0))
    argument_map["om_cost_ip"] = om_cost_ip

    om_frequency = arguments[count += 1].clone
    assert(om_frequency.setValue(1))
    argument_map["om_frequency"] = om_frequency

    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "Success")

  end

  def test_ReplaceExteriorWindowConstruction_EmptySpaceNoLoadsOrSurfaces

    # create an instance of the measure
    measure = ReplaceExteriorWindowConstruction.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # add a space to the model without any geometry or loads, want to make sure measure works or fails gracefully
    new_space = OpenStudio::Model::Space.new(model)

    # make simple glazing material and then a construction to use it
    window_mat =  OpenStudio::Model::SimpleGlazing.new(model)
    window_const = OpenStudio::Model::Construction.new(model)
    window_const.insertLayer(0,window_mat)

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(11, arguments.size)
    assert_equal("construction", arguments[0].name)
    assert((not arguments[0].hasDefaultValue))

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    construction = arguments[count += 1].clone
    assert(construction.setValue(window_const.name.to_s))
    argument_map["construction"] = construction

    change_fixed_windows = arguments[count += 1].clone
    assert(change_fixed_windows.setValue(true))
    argument_map["change_fixed_windows"] = change_fixed_windows

    change_operable_windows = arguments[count += 1].clone
    assert(change_operable_windows.setValue(false))
    argument_map["change_operable_windows"] = change_operable_windows

    remove_costs = arguments[count += 1].clone
    assert(remove_costs.setValue(true))
    argument_map["remove_costs"] = remove_costs

    material_cost_ip = arguments[count += 1].clone
    assert(material_cost_ip.setValue(0))
    argument_map["material_cost_ip"] = material_cost_ip

    demolition_cost_ip = arguments[count += 1].clone
    assert(demolition_cost_ip.setValue(0))
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
    assert(om_cost_ip.setValue(0))
    argument_map["om_cost_ip"] = om_cost_ip

    om_frequency = arguments[count += 1].clone
    assert(om_frequency.setValue(1))
    argument_map["om_frequency"] = om_frequency

    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "NA")

  end

end


