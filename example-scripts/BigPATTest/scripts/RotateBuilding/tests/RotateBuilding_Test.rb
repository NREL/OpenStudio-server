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

class RotateBuilding_Test < Test::Unit::TestCase
  
  # def setup
  # end

  # def teardown
  # end
  
  def test_RotateBuilding
     
    # create an instance of the measure
    measure = RotateBuilding.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # make an empty model
    model = OpenStudio::Model::Model.new
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
    assert_equal("relative_building_rotation", arguments[0].name)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/RotateBuilding_TestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    relative_building_rotation = arguments[0].clone
    assert(relative_building_rotation.setValue("500.2"))
    argument_map["relative_building_rotation"] = relative_building_rotation

    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 2)
    assert(result.info.size == 1)
    
  end

  # this was just made to test if building object was made on new model. It it was not then rotate building woudl not have worked.
  def test_RotateBuilding_EmptySpaceNoLoadsOrSurfaces

    # create an instance of the measure
    measure = RotateBuilding.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
    assert_equal("relative_building_rotation", arguments[0].name)

    # make an empty model
    model = OpenStudio::Model::Model.new

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    relative_building_rotation = arguments[0].clone
    assert(relative_building_rotation.setValue("500.2"))
    argument_map["relative_building_rotation"] = relative_building_rotation

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    #assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 2)
    #assert(result.info.size == 1)

  end

end


