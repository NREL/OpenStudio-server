# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

jsonfile = "/data/pat/server_problem.json"
if File.exists?(jsonfile)
  json = JSON.parse(File.read(jsonfile), :symbolize_names => true)

  project = Project.find_or_create_by(:name => "Example 1")
  project.create_single_analysis("PAT Example", "Batch")
  project.save!

  problem = project.get_problem("Batch")

  problem.load_variables_from_pat_json(json)
  problem.save!


  # load the datapoints from pat that need to be run
  datapoint_file =  "/data/pat/server_datapoints_request.json"
  if File.exists?(datapoint_file)
    json = JSON.parse(File.read(datapoint_file), :symbolize_names => true)

    analysis = project.analyses.where(name: "PAT Example").first
    json[:datapoints].each do |datum|
      datapoint = analysis.data_points.find_or_create_by(uuid: datum[:uuid])

      puts datapoint.inspect
      #save the rest of the values to the database
      datum.each_key do |key|
        next if key == 'uuid'

        datapoint[key] = datum[key]
      end
      datapoint.save!
    end

  end
else
  puts "File #{datapoint_file} does not exist"
end



