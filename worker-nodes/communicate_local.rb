require 'openstudio'

module CommunicateLocal
  def self.communicate_started(run_dir)
    puts "Running DataPoint in #{run_dir}."
  end

  def self.communicate_log_message(run_dir, log_message, add_delta_time = false, prev_time = nil)
    puts log_message
  end

  def self.get_datapoint(run_dir)
    run_dir
  end

  def self.get_problem(run_dir, format)
    result = [] # [data_point_json, analysis_json]

    run_dir = OpenStudio::Path.new(run_dir)
    project_path = run_dir.parent_path

    # verify the existence of required files
    data_point_json_path = run_dir / OpenStudio::Path.new('data_point_in.json')
    fail "Required file '" + data_point_json_path.to_s + "' does not exist." unless File.exist?(data_point_json_path.to_s)
    File.open(data_point_json_path.to_s, 'r') do |f|
      result[0] = f.read
    end

    formulation_json_path = project_path / OpenStudio::Path.new('formulation.json')
    fail "Required file '" + formulation_json_path.to_s + "' does not exist." unless File.exist?(formulation_json_path.to_s)
    File.open(formulation_json_path.to_s, 'r') do |f|
      result[1] = f.read
    end

    result
  end

  def self.communicate_results(run_dir, os_data_point, os_directory)
    data_point_json_path = OpenStudio::Path.new(run_dir) / OpenStudio::Path.new('data_point_out.json')
    os_data_point.saveJSON(data_point_json_path, true)

    puts 'Run complete.'
  end

  def self.communicate_results_json(run_dir, eplus_json, analysis_dir)
    # no-op
  end

  def self.communicate_complete(dp)
    puts 'Run completed normally.'
  end

  def self.communicate_failure(dp, os_directory)
    # os_directory can be nil, but nothing happens here... move along
    puts 'Run failed.'
  end

  def self.reload(dp)
    # no-op
  end
end
