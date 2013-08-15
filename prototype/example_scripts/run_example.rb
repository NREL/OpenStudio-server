require 'rest-client'
require 'json'

HOSTNAME = "http://localhost:8080"


#  --------- GET example -----------
resp = RestClient.get("#{HOSTNAME}/projects.json")

json = JSON.parse(resp)
puts json.inspect

analysis_id = json[0]['analyses'][0]['_id']
puts analysis_id

datapoints = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}.json")
puts JSON.pretty_generate(JSON.parse(datapoints))



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
end

# create a new analysis
analysis_id = nil
if !project_id.nil?
  analysis_hash = { analysis: { project_id: project_id, name: "script example"} }

  resp = RestClient.post("#{HOSTNAME}/projects/#{project_id}/analyses.json", analysis_hash)

  if resp.code == 201

    analysis_id = JSON.parse(resp)["_id"]
    puts "new analysis created with ID: #{analysis_id}"
  end
end


# add all the datapoints to the analysis
if !analysis_id.nil?
  dp_json = JSON.parse(File.open("../pat/server_datapoints_request.json").read, :symbolize_names => true)

  dp_json[:data_points].each do |dp|
    dp_hash = { data_point: dp.merge({analysis_id: analysis_id}) }    # TODO merge in the rest of the datapoint hash

    resp = RestClient.post("#{HOSTNAME}/analyses/#{analysis_id}/data_points.json", dp_hash)
    if resp.code == 201
      puts "new datapoint created for #{analysis_id}"
    end
  end

end


# run the analysis
if !analysis_id.nil?
  # run the analysis

  action_hash = { action: "start" }

  resp = RestClient.post("#{HOSTNAME}/analyses/#{analysis_id}/action.json", action_hash)

  puts resp

end

# get the status of all the entire analysis
if !analysis_id.nil?
  resp = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}/status.json")
  puts resp

  resp = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}/status.json?jobs=running")
  puts resp

  resp = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}/status.json?jobs=queued")
  puts resp

  resp = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}/status.json?jobs=complete")

  puts resp
end





