# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

jsonfile = Dir.glob("/data/prototype/pat/analysis*/formulation.json").first
if File.exists?(jsonfile)
  json = JSON.parse(File.read(jsonfile), :symbolize_names => true)


  project = Project.find_or_create_by(name: json[:analysis][:problem][:name])
  # There is no Project UUID at the moment. Just create a new one.
  #project.uuid = :uuid => UUID.generate
  project.create_single_analysis(json[:analysis][:uuid], "PAT Example", json[:analysis][:problem][:uuid], "Batch")
  project.save!

  problem = project.get_problem("Batch")
  problem.load_variables_from_pat_json(json)
  problem.save!

  # load the datapoints from pat that need to be run
  datapoint_files = Dir.glob("/data/prototype/pat/analysis*/data_point*/data_point_in.json")
  datapoint_files.each do |datapoint_file|
    puts "loading #{datapoint_file}"
    if File.exists?(datapoint_file)
      analysis = project.analyses.where(name: "PAT Example").first
      dp = JSON.parse(File.read(datapoint_file), :symbolize_names => true)[:data_point]
      datapoint = analysis.data_points.find_or_create_by(uuid: dp[:uuid])

      puts datapoint.inspect
      #save the rest of the values to the database
      dp.each_key do |key|
        next if key == 'uuid'

        datapoint[key] = dp[key]
      end
      datapoint.save!

    end
    puts "File #{datapoint_file} does not exist"
  end

else
  puts "File #{jsonfile} does not exist"
end



