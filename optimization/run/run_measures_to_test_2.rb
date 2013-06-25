
require 'openstudio'
require "C:/Projects/openstudio-r/optimization/TestRunUserScript"

puts "" #space for readability of output in console
puts ""

#define the model in and the model out path
in_file_path = "C:/Projects/openstudio-r/optimization/test/seed_model.osm"
out_file_path = "C:/Projects/openstudio-r/optimization/test/result1.osm"

#Temp argument and measure location
args = {
"wwr" => 0.1,
"sillHeight" => 30.0,
"facade" => "south",
"proposed_material_cost" => 0.0,
"proposed_installation_cost" => 0.0,
"proposed_recurring_cost" => 0.0,
"expected_life" => 10
}
test_run_user_script("C:/Projects/openstudio-r/optimization/test/measure_wwr.rb",in_file_path,out_file_path,args)

#rotation
in_file_path = "C:/Projects/openstudio-r/optimization/test/result1.osm"
out_file_path = "C:/Projects/openstudio-r/optimization/test/result2.osm"

  args = {
       "relative_building_rotation" => 36.0}
  test_run_user_script("C:/Projects/openstudio-r/optimization/test/measure_rotation.rb", in_file_path, out_file_path, args)
 
in_file_path = "C:/Projects/openstudio-r/optimization/test/result2.osm"
out_file_path = "C:/Projects/openstudio-r/optimization/test/result3.osm" 
 
  #LPD
  args = {
      "space_type" => "*Entire Building*",
      "lpd" => 3.0,
      "units" => "CostPerArea",
      "baseline_material_cost" => 0.0,
      "baseline_installation_cost" => 0.0,
      "baseline_demolition_cost" => 0.0,
      "baseline_salvage_value" => 0.0,
      "baseline_recurring_cost" => 0.0,
      "proposed_material_cost" => 0.0,
      "proposed_installation_cost" => 0.0,
      "proposed_demolition_cost" => 0.0,
      "proposed_salvage_value" => 0.0,
      "proposed_recurring_cost" => 0.0,
      "recurring_cost_frequency" => 0.0,
      "expected_life" => 10,
      "retrofit" => "retrofit",
  }
  test_run_user_script("C:/Projects/openstudio-r/optimization/test/measure_lpd.rb", in_file_path, out_file_path, args)
  
in_file_path = "C:/Projects/openstudio-r/optimization/test/result3.osm"
out_file_path = "C:/Projects/openstudio-r/optimization/test/result4.osm" 
 
  #WallR
  args = {
      "r_value" => 10.0,
      "baseline_material_cost" => 0.0,
      "baseline_installation_cost" => 10.0,
      "baseline_demolition_cost" => 0.0,
      "baseline_salvage_value" => 0.0,
      "baseline_recurring_cost" => 0.0,
      "proposed_material_cost" => 0.0,
      "proposed_installation_cost" => 0.0,
      "proposed_demolition_cost" => 0.0,
      "proposed_salvage_value" => 0.0,
      "proposed_recurring_cost" => 0.0,
      "recurring_cost_frequency" => 0.0,
      "expected_life" => 10,
      "retrofit" => "retrofit",
  }
  test_run_user_script("C:/Projects/openstudio-r/optimization/test/measure_wallR.rb", in_file_path, out_file_path, args)  
  
in_file_path = "C:/Projects/openstudio-r/optimization/test/result4.osm"
out_file_path = "C:/Projects/openstudio-r/optimization/test/result5.osm" 
 
  #roofR
  args = {
      "r_value" => 20.0,
      "baseline_material_cost" => 0.0,
      "baseline_installation_cost" => 10.0,
      "baseline_demolition_cost" => 0.0,
      "baseline_salvage_value" => 0.0,
      "baseline_recurring_cost" => 0.0,
      "proposed_material_cost" => 0.0,
      "proposed_installation_cost" => 0.0,
      "proposed_demolition_cost" => 0.0,
      "proposed_salvage_value" => 0.0,
      "proposed_recurring_cost" => 0.0,
      "recurring_cost_frequency" => 0.0,
      "expected_life" => 10,
      "retrofit" => "retrofit",
  }
  test_run_user_script("C:/Projects/openstudio-r/optimization/test/measure_roofR.rb", in_file_path, out_file_path, args)   
  
in_file_path = "C:/Projects/openstudio-r/optimization/test/result5.osm"
out_file_path = "C:/Projects/openstudio-r/optimization/test/result6.osm" 
 
  #lifecycle
  args = {
      "study_period" => 25.0,
  }
  test_run_user_script("C:/Projects/openstudio-r/optimization/test/measure_lifecycle.rb", in_file_path, out_file_path, args)   
 
 
 #daylight
#  args = {
#      "space_type" => "*Entire Building*",
#      "setpoint" => 30.0,
#      "control_type" => "Continuous/Off",
#      "min_power_fraction" => 0.3,
#      "min_light_fraction" => 0.2,
#      "height" => 30.0,
#      "units" => "Cost Units",
#      "baseline_material_cost" => 0.0,
#      "baseline_installation_cost" => 0.0,
#      "baseline_demolition_cost" => 0.0,
#      "baseline_salvage_value" => 0.0,
#      "baseline_recurring_cost" => 0.0,
#      "proposed_material_cost" => 0.0,
#      "proposed_installation_cost" => 0.0,
#      "proposed_demolition_cost" => 0.0,
#      "proposed_salvage_value" => 0.0,
#      "proposed_recurring_cost" => 0.0,
#      "recurring_cost_frequency" => 0.0,
#      "expected_life" => 10,
#      "retrofit" => "retrofit",
#  }
#  test_run_user_script("C:/Projects/openstudio-r/optimization/test/measure_daylight.rb", in_file_path, out_file_path, args)   


#  #Thermostat
#  args = {
#      "cooling_adjustment" => 2.0,
#      "heating_adjustment" => -1.0,
#  }
#  test_run_user_script("C:/Projects/openstudio-r/optimization/test/measure_thermostat.rb", in_file_path, out_file_path, args)     