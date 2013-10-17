require 'rest-client'
require 'json'
require 'faraday'

HOSTNAME = "http://localhost:8080"
WITHOUT_DELAY=true # NOTE that this is for only the LHS portion the batch is asynchronous.
ANALYSIS_TYPE="sequential_search"
STOP_AFTER_N=nil  #set to nil if you want them all
                  #HOSTNAME = "http://ec2-107-22-88-62.compute-1.amazonaws.com"

                  # Project data
formulation_file = "./ContinuousExample/analysis_discrete.json"
analysis_zip_file = "./ContinuousExample/analysis.zip"
#datapoints = Dir.glob("./BigPATTestExport/datapoint*.json")

# Try not to change data below here. If you do make sure you update the other run_example file
@conn = Faraday.new(:url => HOSTNAME) do |faraday|
  faraday.request  :url_encoded             # form-encode POST params
  faraday.response :logger                  # log requests to STDOUT
  faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
end

# -------- DELETE Example ----------
resp = RestClient.get("#{HOSTNAME}/projects.json")

projects_json = JSON.parse(resp, :symbolize_names => true, :max_nesting => false)
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
  formulation_json = JSON.parse(File.read(formulation_file), :symbolize_names => true)

  analysis_id = formulation_json[:analysis][:uuid]

  formulation_json[:analysis][:name] = "running from #{File.basename(__FILE__)}"

  # save out this file to compare
  #File.open('formulation_merge.json','w'){|f| f << JSON.pretty_generate(formulation_json)}

  resp = @conn.post do |req|
    req.url "projects/#{project_id}/analyses.json"
    req.headers['Content-Type'] = 'application/json'
    req.body = formulation_json.to_json
  end

  puts resp.inspect
  if resp.status == 201
    puts "asked to create analysis with #{analysis_id}"
    #puts resp.inspect
    analysis_id = JSON.parse(resp.body)["_id"]

    puts "new analysis created with ID: #{analysis_id}"
  end
end

# add the seed model, measures, etc to the analysis
if !analysis_id.nil?
  puts "uploading seed zip file"

  if File.exist?(analysis_zip_file)
    resp = RestClient.post("#{HOSTNAME}/analyses/#{analysis_id}/upload.json", :file => File.open(analysis_zip_file, 'rb'))
    #puts resp
    puts resp.code

    if resp.code == 201
      puts "Successfully uploaded ZIP file"
    end
  else
    raise "Analysis zip file does not exist! #{analysis_zip_file}"
  end
end

# run the analysis and let LHS determine the measure group items -- at least try it.
if !analysis_id.nil?
  # run the analysis


  action_hash = { analysis_action: "start", without_delay: WITHOUT_DELAY, analysis_type: ANALYSIS_TYPE }
  puts action_hash.to_json


  #resp = @conn.post do |req|
  #  req.url "analyses/#{analysis_id}/action.json"
  #  req.headers['Content-Type'] = 'application/json'
  #  req.body = action_hash.to_json
  #req.options[:timeout] = 180 #seconds
  #end
  #puts resp.status

  a = Time.now
  puts a
  resp = RestClient.post("#{HOSTNAME}/analyses/#{analysis_id}/action.json", action_hash, :timeout => 300)
  puts resp.code
  b = Time.now
  puts b
  puts "delta #{b.to_f - a.to_f}"

  # check all the queued analyses for this project (eventually move this to all analyses)
  #puts "list of queued analyses"
  #resp = RestClient.get("#{HOSTNAME}/projects/#{project_id}/status.json?jobs=queued")
  #puts resp

  action_hash = { analysis_action: "start", without_delay: false, analysis_type: 'batch_run', simulate_data_point_filename: 'simulate_data_point_lhs.rb' }
  puts action_hash.to_json

  a = Time.now
  puts a
  resp = RestClient.post("#{HOSTNAME}/analyses/#{analysis_id}/action.json", action_hash, :timeout => 300)
  puts resp.code
  b = Time.now
  puts b
  puts "delta #{b.to_f - a.to_f}"


end





