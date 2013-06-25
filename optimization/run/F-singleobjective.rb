#puts "test"
require 'openstudio'
require 'rubygems'
require 'uuid'
require 'csv'
require 'fileutils'
require "C:/Projects/openstudio-r/optimization/TestRunUserScript"


# use option parser eventually
x1=ARGV[0] #LPD
x2=ARGV[1] #rotation
x3=ARGV[2] #WWR
x4=ARGV[3] #WallR
x5=ARGV[4] #RoofR


def create_idf_file(osm_filename)
  input_file_path = OpenStudio::Path.new(osm_filename)

  versionTranslator = OpenStudio::OSVersion::VersionTranslator.new
  model = versionTranslator.loadModel(input_file_path)
  if model.empty?
    puts "Version translation failed for #{model_path_string}"
    exit
  else
    model = model.get
  end

  #Forward translate EnergyPlus file
  forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new()
  #puts "starting forward translator #{Time.now}"
  idf = forward_translator.translateModel(model)

  idf_filename = "#{File.dirname(osm_filename)}/result.idf"
  File.open(idf_filename, 'w') {|f| f << idf}

  idf_filename
end

def create_model_lpd(path, argv)
  x1=ARGV[0] #LPD
  x2=ARGV[1] #Rotation
  x3=ARGV[2] #WWR
  x4=ARGV[3] #WallR
  x5=ARGV[4] #RoofR


#	puts "" #space for readability of output in console
#	puts ""

#define the model in and the model out path
  in_file_path = "C:/Projects/openstudio-r/optimization/seed/seed_model.osm"
  out_file_path = "#{path}/result1.osm"

  #LPD
  args = {
      "space_type" => "*Entire Building*",
      "lpd" => x1,
      "units" => "CostPerArea",
      "baseline_material_cost" => 0.0,
      "baseline_installation_cost" => 0.0,
      "baseline_demolition_cost" => 0.0,
      "baseline_salvage_value" => 0.0,
      "baseline_recurring_cost" => 0.0,
      "proposed_material_cost" => 1.0*x1.to_f,
      "proposed_installation_cost" => 0.0,
      "proposed_demolition_cost" => 0.0,
      "proposed_salvage_value" => 0.0,
      "proposed_recurring_cost" => 1.0*x1.to_f,
      "recurring_cost_frequency" => 1.0,
      "expected_life" => 10,
      "retrofit" => "retrofit",
  }
  test_run_user_script("C:/Projects/openstudio-r/optimization/measures/measure_LPD.rb", in_file_path, out_file_path, args)
end

def create_model_rotation(path, argv)
  x1=ARGV[0] #LPD
  x2=ARGV[1] #Rotation
  x3=ARGV[2] #WWR
  x4=ARGV[3] #WallR
  x5=ARGV[4] #RoofR

#rotation
in_file_path = "#{path}/result1.osm"
out_file_path = "#{path}/result2.osm"
#out_file_path = "#{path}/result.osm"
  args = {
       "relative_building_rotation" => x2}
  test_run_user_script("C:/Projects/openstudio-r/optimization/measures/measure_rotation.rb", in_file_path, out_file_path, args)
end

def create_model_wwr(path, argv)
  x1=ARGV[0] #LPD
  x2=ARGV[1] #Rotation
  x3=ARGV[2] #WWR
  x4=ARGV[3] #WallR
  x5=ARGV[4] #RoofR
#WWR
in_file_path = "#{path}/result2.osm"
out_file_path = "#{path}/result3.osm"
#out_file_path = "#{path}/result.osm"
args = {
"wwr" => x3,
"sillHeight" => 30.0,
"facade" => "south",
"proposed_material_cost" => 1.0*x3.to_f,
"proposed_installation_cost" => 0.0,
"proposed_recurring_cost" => 1.0*x3.to_f,
"expected_life" => 10
}
  test_run_user_script("C:/Projects/openstudio-r/optimization/measures/measure_wwr.rb", in_file_path, out_file_path, args)
#  out_file_path
end

def create_model_wallr(path, argv)
  x1=ARGV[0] #LPD
  x2=ARGV[1] #Rotation
  x3=ARGV[2] #WWR
  x4=ARGV[3] #WallR
  x5=ARGV[4] #RoofR
in_file_path = "#{path}/result3.osm"
out_file_path = "#{path}/result4.osm"
#out_file_path = "#{path}/result.osm"
 
  #WallR
  args = {
      "r_value" => x4,
      "baseline_material_cost" => 0.0,
      "baseline_installation_cost" => 0.0,
      "baseline_demolition_cost" => 0.0,
      "baseline_salvage_value" => 0.0,
      "baseline_recurring_cost" => 0.0,
      "proposed_material_cost" => 2.0*x4.to_f,
      "proposed_installation_cost" => 0.0,
      "proposed_demolition_cost" => 0.0,
      "proposed_salvage_value" => 0.0,
      "proposed_recurring_cost" => 2.0*x4.to_f,
      "recurring_cost_frequency" => 1.0,
      "expected_life" => 10,
      "retrofit" => "retrofit",
  }
  test_run_user_script("C:/Projects/openstudio-r/optimization/measures/measure_wallR.rb", in_file_path, out_file_path, args)  
 # out_file_path
end

def create_model_roofr(path, argv)
  x1=ARGV[0] #LPD
  x2=ARGV[1] #Rotation
  x3=ARGV[2] #WWR
  x4=ARGV[3] #WallR
  x5=ARGV[4] #RoofR
in_file_path = "#{path}/result4.osm"
out_file_path = "#{path}/result5.osm"
 
  #roofR
  args = {
      "r_value" => x5,
      "baseline_material_cost" => 0.0,
      "baseline_installation_cost" => 0.0,
      "baseline_demolition_cost" => 0.0,
      "baseline_salvage_value" => 0.0,
      "baseline_recurring_cost" => 0.0,
      "proposed_material_cost" => 1.0*x5.to_f,
      "proposed_installation_cost" => 0.0,
      "proposed_demolition_cost" => 0.0,
      "proposed_salvage_value" => 0.0,
      "proposed_recurring_cost" => 1.0*x5.to_f,
      "recurring_cost_frequency" => 1.0,
      "expected_life" => 10,
      "retrofit" => "retrofit",
  }
  test_run_user_script("C:/Projects/openstudio-r/optimization/measures/measure_roofR.rb", in_file_path, out_file_path, args)   
  
  out_file_path
end

def create_model_lifecycle(path, argv)
  in_file_path = "#{path}/result5.osm"
  out_file_path = "#{path}/result.osm"
  #lifecycle
  args = {
      "study_period" => 25.0,
  }
  test_run_user_script("C:/Projects/openstudio-r/optimization/test/measure_lifecycle.rb", in_file_path, out_file_path, args)   
  out_file_path
end

def check_finished(run_path)
  #this is actually a cal lt ot teh run manager database to check
  #if the simulation is complete 
  puts run_path
  File.exists?("#{run_path}/done.receipt")
end

def run_model_single(run_path, idf_filename, osm_filename, weather_filename, support_files, run_args = nil)
  FileUtils.copy("./run_energyplus.rb", "#{run_path}/")
  command = "ruby #{run_path}/run_energyplus.rb -a #{run_path} -i #{idf_filename} -o #{osm_filename} \
-w #{File.expand_path("./weatherdata/"+weather_filename)} -p #{File.expand_path("./supportfiles/postproc.rb")}"
  command += " -e #{run_args[:energyplus]}" unless run_args.nil?
  command += " --idd-path #{run_args[:idd]}" unless run_args.nil?
  command += " --support-files #{support_files}" unless support_files.nil?
  puts command
  puts `#{command}`
end


#save simulation to run manager

file_path = File.expand_path(FileUtils.mkdir_p("sims/#{UUID.new.generate}"))
create_model_lpd(file_path, ARGV)
create_model_rotation(file_path, ARGV)
create_model_wwr(file_path, ARGV)
create_model_wallr(file_path, ARGV)
create_model_roofr(file_path, ARGV)
osm_filename = create_model_lifecycle(file_path, ARGV)

puts "create osm with name: #{osm_filename}"
idf_filename = create_idf_file(osm_filename)
puts "create osm with name: #{idf_filename}"
weather_filename = "USA_CO_Golden-NREL.724666_TMY3.epw"

run_args = {
    :energyplus => "C:/EnergyPlusV7-2-0/EnergyPlus.exe",
    :idd => "C:/EnergyPlusV7-2-0/Energy+.idd"
}

run_model_single(file_path, idf_filename, osm_filename, weather_filename, nil, run_args)

while not check_finished(file_path)
  sleep(1)
end

i_row = 0
eui = nil
CSV.foreach("#{file_path}/run/eplustbl.csv") do |row|
  # use row here...
  i_row += 1
  if i_row == 2
    eui = row[0]
  end
end
#eui = 1.0
if eui.nil?
  eui = 0.0
end

#f = 5000/x2.to_f + 80 + 50*x1.to_f + 100
#puts f

# print out the eui so that R can parse and continue optimization
puts eui.to_f