require 'rest-client'
require 'json'
require 'faraday'

HOSTNAME = "http://localhost:8080"
WITHOUT_DELAY=false
#HOSTNAME = "http://ec2-107-22-88-62.compute-1.amazonaws.com"

@conn = Faraday.new(:url => HOSTNAME) do |faraday|
  faraday.request  :url_encoded             # form-encode POST params
  faraday.response :logger                  # log requests to STDOUT
  faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
end

#  --------- GET & Kill all running analyses example -----------
resp = RestClient.get("#{HOSTNAME}/projects.json")

projects_json = JSON.parse(resp, :symbolize_names => true, :max_nesting => false)
#puts projects_json.inspect
if projects_json.count > 0
  if !projects_json[0][:analyses].nil?
    analysis_id = projects_json[0][:analyses][0][:_id]
    puts analysis_id

    #datapoints = RestClient.get("#{HOSTNAME}/analyses/#{analysis_id}.json")
    #puts JSON.parse(datapoints, :max_nesting => false)
    #puts JSON.pretty_generate(JSON.parse(datapoints))
  end

  # Uncomment this section to test the stop
  action_hash = { analysis_action: "stop" }
  puts action_hash.to_json

  resp = RestClient.post("#{HOSTNAME}/analyses/#{analysis_id}/action.json", action_hash, :timeout => 300)
  puts resp.inspect
end