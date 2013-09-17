require 'rest-client'
require 'json'

HOSTNAME = "http://localhost:8080"


#  --------- GET example -----------
resp = RestClient.get("#{HOSTNAME}/projects.json")

projects_json = JSON.parse(resp, :symbolize_names => true, :max_nesting => false)

if projects_json.count > 0
  analysis_id = projects_json[0][:analyses][0][:_id]
  puts analysis_id

  datapoints = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}.json")
  puts JSON.parse(datapoints, :max_nesting => false)
  #puts JSON.pretty_generate(JSON.parse(datapoints))
end

# -------- DELETE Example ----------
puts "Deleting all projects in database!"

projects_json.each do |project|
  puts "Deleting Project #{project[:uuid]}"
  resp = RestClient.delete("#{HOSTNAME}/projects/#{project[:uuid]}.json")
  puts resp.code
end


# ------- add new project and run example ----------
project_name = "project #{(rand()*1000).round}"
puts project_name

project_hash = { project: { name: "#{project_name}" } }
puts project_hash

resp = RestClient.post("#{HOSTNAME}/projects.json", project_hash)
puts resp.code

# create a new project
project_id = nil
if resp.code == 201
  project_id = JSON.parse(resp)["_id"]

  puts "new project created with ID: #{project_id}"
  #grab the project id
elsif resp.code == 500
  puts "500 Error"
  puts resp.inspect
end

# create a new analysis
analysis_id = nil
if !project_id.nil?
  formulation_file = "../pat/analysis/formulation.json"
  formulation_json = JSON.parse(File.read(formulation_file), :symbolize_names => true)
  analysis_id = formulation_json[:analysis][:uuid]

  analysis_hash = { analysis: { project_id: project_id, name: "script example", uuid: analysis_id } }
  puts analysis_hash.inspect

  resp = RestClient.post("#{HOSTNAME}/projects/#{project_id}/analyses.json", analysis_hash)
  puts resp.inspect

  if resp.code == 201
    analysis_id = JSON.parse(resp)["_id"]
    puts "new analysis created with ID: #{analysis_id}"
  end
end


# add the seed model, measures, etc to the analysis
if !analysis_id.nil?
  puts "uploading seed zip file"
  file = "../pat/analysis.zip"

  if File.exist?(file)
    resp = RestClient.post("#{HOSTNAME}/analyses/#{analysis_id}/upload.json", :file => File.open(file, 'rb'))
    puts resp
    puts resp.code

    if resp.code == 201
      puts "Successfully uploaded ZIP file"
    end
  else
    raise "Analysis zip file does not exist! #{file}"
  end
end



# add all the datapoints to the analysis
if !analysis_id.nil?
  datapoints = Dir.glob("../pat/analysis*/data_point*/data_point_in.json")
  datapoints.each do |dp|
    puts "reading in datapoint json: #{dp}"
    dp_hash = JSON.parse(File.open(dp).read, :symbolize_names => true)

    # merge in the analysis_id as it has to be what is in the database
    dp_hash[:data_point][:analysis_id] = analysis_id
    puts dp_hash.inspect

    url = "#{HOSTNAME}/analyses/#{analysis_id}/data_points.json"
    puts url
    resp = RestClient.post(url, dp_hash)
    if resp.code == 201
      puts "new datapoint created for analysis #{analysis_id}"
      puts resp
    end
  end
end


# run the analysis
if !analysis_id.nil?
  # run the analysis

  action_hash = { analysis_action: "start" }
  #action_hash = { action: "stop"}

  resp = RestClient.post("#{HOSTNAME}/analyses/#{analysis_id}/action.json", action_hash)
  puts resp.inspect
  exit

  # check all the queued analyses for this project (eventually move this to all analyses)
  puts
  puts "list of queued analyses"
  resp = RestClient.get("#{HOSTNAME}/projects/#{project_id}/status.json?jobs=queued")
  puts resp
end

# get the status of all the entire analysis
if !analysis_id.nil?
  resp = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}/status.json")
  puts "Data points (all): #{resp}"

  resp = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}/status.json?jobs=running")
  puts "Data points (running): #{resp}"

  resp = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}/status.json?jobs=queued")
  puts "Data points (queued): #{resp}"

  resp = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}/status.json?jobs=complete")

  puts "Data points (complete): #{resp}"
end





