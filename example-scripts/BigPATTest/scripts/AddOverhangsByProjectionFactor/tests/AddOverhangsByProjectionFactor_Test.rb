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

class AddOverhangsByProjectionFactor_Test < Test::Unit::TestCase
  
  # def setup
  # end

  # def teardown
  # end

  def test_AddOverhangsByProjectionFactor_bad

    # create an instance of the measure
    measure = AddOverhangsByProjectionFactor.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(4, arguments.size)
    assert_equal("projection_factor", arguments[0].name)
    assert_equal("facade", arguments[1].name)
    assert_equal("remove_ext_space_shading", arguments[2].name)
    assert_equal("construction", arguments[3].name)

    # set argument values to bad values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    projection_factor = arguments[0].clone
    assert(projection_factor.setValue("-20"))
    argument_map["projection_factor"] = projection_factor
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == "Fail")

  end

  def test_AddOverhangsByProjectionFactor_good

    # create an instance of the measure
    measure = AddOverhangsByProjectionFactor.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/OverhangTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    projection_factor = arguments[0].clone
    assert(projection_factor.setValue(0.5))
    argument_map["projection_factor"] = projection_factor
    facade = arguments[1].clone
    assert(facade.setValue("South"))
    argument_map["facade"] = facade
    remove_ext_space_shading = arguments[2].clone
    assert(remove_ext_space_shading.setValue(false))
    argument_map["remove_ext_space_shading"] = remove_ext_space_shading
    construction = arguments[3].clone
    assert(construction.setValue("000_Interior Partition"))
    argument_map["construction"] = construction
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 1)
    assert(result.info.size == 3)

    #save the model
    #puts "saving model"
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)

  end

  def test_AddOverhangsByProjectionFactor_good_noDefault

    # create an instance of the measure
    measure = AddOverhangsByProjectionFactor.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/OverhangTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    projection_factor = arguments[0].clone
    assert(projection_factor.setValue(0.5))
    argument_map["projection_factor"] = projection_factor
    facade = arguments[1].clone
    assert(facade.setValue("South"))
    argument_map["facade"] = facade
    remove_ext_space_shading = arguments[2].clone
    assert(remove_ext_space_shading.setValue(false))
    argument_map["remove_ext_space_shading"] = remove_ext_space_shading
    construction = arguments[3].clone

    argument_map["construction"] = construction
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 1)
    assert(result.info.size == 4)

    #save the model
    #puts "saving model"
    #output_file_path = OpenStudio::Path.new('C:\SVN_Utilities\OpenStudio\measures\test.osm')
    #model.save(output_file_path,true)

  end

end