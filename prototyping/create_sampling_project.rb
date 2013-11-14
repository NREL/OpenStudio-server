# the purpose of this script is to programmatically generate an OpenStudio sampling problem,
# and then export it in openstudio-server format, that is, a .zip and .json files.
# 
# the sampling problem is to be a work-in-progress for now, that is, OpenStudio does not yet 
# have all of the desired features. however, this test can show both what is already available, 
# and, in comments (maybe also puts statements), where we are going in the next 3-9 months.

require 'openstudio'
require 'fileutils'

project_dir = "SamplingProject"

# create new project
if File.exists?(project_dir)
  OpenStudio::removeDirectory(OpenStudio::Path.new(project_dir))
end
project = OpenStudio::AnalysisDriver::SimpleProject::create(OpenStudio::Path.new(project_dir)).get

# specify the seed model
if not File.exists?(project_dir + "/seed")
  Dir.mkdir(project_dir + "/seed")
end
seed_path = OpenStudio::Path.new("example.osm")
model = OpenStudio::Model::exampleModel
model.save(seed_path)
project.setSeed(OpenStudio::FileReference.new(seed_path))
File.delete(seed_path.to_s)
puts "Currently using OpenStudio::Model::example as the seed, but might be better to use some variety of reference building?"

# create the problem formulation
problem = project.analysis.problem

  # (pivot) variable 1: climate zone
  # measure that takes BCL component, sets weather file and design days. 
  # has argument asking which design days.
  # (add ground temperatures later)
  puts "First variable should be pivot on climate zone. Need appropriate measure."
  
  # variable 2: building rotation
  rotate_bldg_measure = OpenStudio::getMeasure("a5be6c96-4ecc-47fa-8d32-f4216ebc2e7d")
  raise "Unable to retrieve rotate building measure from BCL." if rotate_bldg_measure.empty?
  rotate_bldg_measure = rotate_bldg_measure.get  
  rotate_bldg_measure = project.insertMeasure(rotate_bldg_measure)
  args = OpenStudio::Ruleset::getArguments(rotate_bldg_measure,model)
  arg_map = OpenStudio::Ruleset::convertOSArgumentVectorToMap(args)
  measure = OpenStudio::Analysis::RubyMeasure.new(rotate_bldg_measure)
  var = OpenStudio::Analysis::RubyContinuousVariable.new("Building Rotation",
                                                         arg_map["relative_building_rotation"],
                                                         measure)
  dist = OpenStudio::Analysis::UniformDistribution.new(-180.0,179.0)
  var.setUncertaintyDescription(dist)
  problem.push(OpenStudio::Analysis::WorkflowStep.new(var))
  
  # variable 3: economizer control
  enable_economizer_measure = OpenStudio::getMeasure("f8cc920d-8ae3-411a-922f-e6fed3223c4d")
  raise "Unable to retrieve enable economizer control measure from BCL." if enable_economizer_measure.empty?
  enable_economizer_measure = enable_economizer_measure.get
  enable_economizer_measure = project.insertMeasure(enable_economizer_measure)
  args = OpenStudio::Ruleset::getArguments(enable_economizer_measure,model)
  arg_map = OpenStudio::Ruleset::convertOSArgumentVectorToMap(args)
  measure = OpenStudio::Analysis::RubyMeasure.new(enable_economizer_measure)
  puts "Cannot currently switch between economizer control types. Need to add DiscreteVariable type for enumeration arguments."
  arg = arg_map["economizer_type"]
  arg.setValue("FixedDewPointAndDryBulb")
  measure.setArgument(arg)
  var = OpenStudio::Analysis::RubyContinuousVariable.new("Economizer Maximum Dry-Bulb Temperature",
                                                         arg_map["econoMaxDryBulbTemp"],
                                                         measure)
  dist = OpenStudio::Analysis::TriangularDistribution.new(69.0,65.0,72.0)
  var.setUncertaintyDescription(dist)
  problem.push(OpenStudio::Analysis::WorkflowStep.new(var))
  var = OpenStudio::Analysis::RubyContinuousVariable.new("Economizer Maximum Dewpoint Temperature",
                                                         arg_map["econoMaxDewpointTemp"],
                                                         measure)
  dist = OpenStudio::Analysis::TriangularDistribution.new(55.0,53.0,60.0)
  var.setUncertaintyDescription(dist)
  problem.push(OpenStudio::Analysis::WorkflowStep.new(var))  

  # workflow
  work_item = OpenStudio::Runmanager::WorkItem.new("ModelToIdf".to_JobType)
  problem.push(OpenStudio::Analysis::WorkflowStep.new(work_item))
  puts "Should this workflow run EnergyPlus, or just sample the space?"  

# specify algorithm parameters
puts "Cannot yet specify openstudio-server algorithm (name and parameters)."

# save the project
project.save

