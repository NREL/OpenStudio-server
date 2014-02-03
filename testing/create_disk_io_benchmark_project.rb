# based on BigPATTest.
#
# create project with 2^n >= ARGV[0].to_i identical data points
#
# run this script from openstudio-server/testing

require 'openstudio'

source_dir = "BigPATTest"
project_dir = "DiskIOBenchmark"
min_points = ARGV[0].to_i

puts "Creating DiskIOBenchmark from BigPATTest. Want at least " + min_points.to_s + 
     " identical data points."

# open BigPATTest and save as DiskIOBenchmark
if File.exists?(project_dir)
  OpenStudio::removeDirectory(OpenStudio::Path.new(project_dir))
end
project = OpenStudio::AnalysisDriver::SimpleProject::open(OpenStudio::Path.new(source_dir)).get
project = OpenStudio::AnalysisDriver::saveAs(project,OpenStudio::Path.new(project_dir)).get

# delete all existing data points
project.removeAllDataPoints
project.save

# go through InputVariables
problem = project.analysis.problem
n = 0
max_n = 0
problem.variables.each { |var|
  mg = var.to_MeasureGroup.get
  
  if mg.numMeasures(true) == 4
    # use choice 3, make copy if 2^n < min_points
    mg.measures(false).each { |measure|
      measure.setIsSelected(false)
    }
    measure = mg.getMeasure(3)
    measure.setIsSelected(true)
    if 2**n < min_points
      measure_copy = measure.clone.to_Measure.get
      mg.push(measure_copy)
      n += 1
    end
    max_n += 1
  else
    # just leave choice 0 selected
    first = true
    mg.measures(false).each { |measure|
      if first
        raise "Unexpected value of selected." if not measure.isSelected
        first = false
      else
        measure.setIsSelected(false)
      end
    }
  end
}
puts source_dir + " contains " + max_n.to_s + " variables with 3 non-null options."
puts "This script can be used to create benchmark problems with up to " + (2**max_n).to_s + 
     " identical data points."

# verify the value of 2^n
combinatorial_size = problem.combinatorialSize(true).get
if not (combinatorial_size == 2**n)
  raise "Expected problem to have combinatorial size of " + (2**n).to_s + ", but is " + 
        (combinatorial_size).to_s + "."
end

# make sure standard reporting measure is in there
if project.getStandardReportWorkflowStep.empty?
  project.insertStandardReportWorkflowStep
end
  
# set design of experiments algorithm, and create data points with .createIteration
analysis = project.analysis
algorithm = OpenStudio::Analysis::DesignOfExperiments.new(
                OpenStudio::Analysis::DesignOfExperimentsOptions.new("FullFactorial".to_DesignOfExperimentsType))
analysis.setAlgorithm(algorithm)
algorithm.createNextIteration(analysis)

# verify the value of 2^n
num_data_points = analysis.dataPoints.size
if not (num_data_points == 2**n)
  raise "Expected to create " + (2**n).to_s + " data points, but have " + num_data_points.to_s + "."
end

# add names
i = 1
analysis.dataPoints.each { |data_point|
  data_point.setName("Data Point #{i}")
  i += 1
}

# clear algorithm and save
analysis.clearAlgorithm
project.save

puts "Created " + project_dir + " with " + num_data_points.to_s + " identical data points."

