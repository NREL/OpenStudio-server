
require 'openstudio'
require "C:/Projects/openstudio-r/optimization/TestRunUserScript"

puts "" #space for readability of output in console
puts ""

#define the model in and the model out path
in_file_path = "C:/Projects/openstudio-r/optimization/seed/seed_model.osm"
out_file_path = "C:/Projects/openstudio-r/optimization/seed/result.osm"

#Temp argument and measure location
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
test_run_user_script("C:/Projects/openstudio-r/optimization/measures/measure.rb",in_file_path,out_file_path,args)

