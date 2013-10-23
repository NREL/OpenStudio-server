require 'faraday'
require 'json'
require 'uuid'

class ServerApi

  def initialize(options = {})
    defaults = {:hostname => "http://localhost:8080"}
    options = defaults.merge(options)

    raise "no host defined for server api class" if options[:hostname].nil?

    # create connection with basic capabilities
    @conn = Faraday.new(:url => options[:hostname]) do |faraday|
      faraday.request :url_encoded # form-encode POST params
      faraday.response :logger # log requests to STDOUT
      faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
    end

    # create connection to server api with multipart capabilities
    @conn_multipart = Faraday.new(:url => options[:hostname]) do |faraday|
      faraday.request :multipart
      faraday.request :url_encoded # form-encode POST params
      faraday.response :logger # log requests to STDOUT
      faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
    end
  end

  def get_projects()
    response = @conn.get '/projects.json'

    projects_json = nil
    if response.status == 200
      projects_json = JSON.parse(response.body, :symbolize_names => true, :max_nesting => false)
    else
      raise "did not receive a 200 in get_projects"
    end

    projects_json
  end

  def get_project_ids()
    ids = get_projects()
    ids.map { |project| project[:uuid] }
  end

  def delete_all()
    ids = get_project_ids()
    puts "Deleting Projects #{ids}"
    ids.each do |id|
      response = @conn.delete "/projects/#{id}.json"
      if response.status == 200
        puts "Successfully deleted project #{id}"
      else
        puts "ERROR deleting project #{id}"
      end
    end
  end

  def new_project(options = {})
    defaults = {project_name: "project #{(rand()*1000).round}"}
    options = defaults.merge(options)
    project_id = nil

    project_hash = {project: {name: "#{options[:project_name]}"}}

    response = @conn.post do |req|
      req.url "/projects.json"
      req.headers['Content-Type'] = 'application/json'
      req.body = project_hash.to_json
    end

    if response.status == 201
      project_id = JSON.parse(response.body)["_id"]

      puts "new project created with ID: #{project_id}"
      #grab the project id
    elsif response.code == 500
      puts "500 Error"
      puts response.inspect
    end

    project_id
  end

  def get_analyses(project_id)
    analysis_ids = []
    response = @conn.get "/projects/#{project_id}.json"
    if response.status == 200
      puts "received the list of analyses for the project"

      analyses = JSON.parse(response.body, :symbolize_names => true, :max_nesting => false)
      if analyses[:analyses]
        analyses[:analyses].each do |analysis|
          analysis_ids << analysis[:_id]
        end
      end
    end

    analysis_ids
  end

  def new_analysis(project_id, options)
    defaults = {analysis_name: "Test Analysis", reset_uuids: false}
    options = defaults.merge(options)

    raise "No project id passed" if project_id.nil?
    raise "no formulation passed to new_analysis" if !options[:formulation_file]
    raise "No formation exists #{options[:formulation_file]}" if !File.exists?(options[:formulation_file])

    formulation_json = JSON.parse(File.read(options[:formulation_file]), :symbolize_names => true)


    # read in the analysis id from the analysis.json file
    analysis_id = nil
    if options[:reset_uuids]
      analysis_id = UUID.new.generate
      formulation_json[:analysis][:uuid] = analysis_id
    else
      analysis_id = formulation_json[:analysis][:uuid]
    end
    raise "No analysis id defined in analyis.json #{options[:formulation_file]}" if analysis_id.nil?

      # set the analysis name
    formulation_json[:analysis][:name] = "#{options[:analysis_name]}"

    # save out this file to compare
    #File.open('formulation_merge.json','w'){|f| f << JSON.pretty_generate(formulation_json)}

    response = @conn.post do |req|
      req.url "projects/#{project_id}/analyses.json"
      req.headers['Content-Type'] = 'application/json'
      req.body = formulation_json.to_json
    end

    if response.status == 201
      puts "asked to create analysis with #{analysis_id}"
      #puts resp.inspect
      analysis_id = JSON.parse(response.body)["_id"]

      puts "new analysis created with ID: #{analysis_id}"
    else
      raise "Could not create new analysis"
    end

    # check if we need to upload the analysis zip file
    if options[:upload_file]
      raise "upload file does not exist #{options[:upload_file]}" if !File.exists?(options[:upload_file])

      payload = {:file => Faraday::UploadIO.new(options[:upload_file], 'application/zip')}
      response = @conn_multipart.post "analyses/#{analysis_id}/upload.json", payload

      if response.status == 201
        puts "Successfully uploaded ZIP file"
      else
        raise response.inspect
      end
    end

    analysis_id
  end

  def upload_datapoint(analysis_id, options)
    defaults = {reset_uuids: false}
    options = defaults.merge(options)

    raise "No analysis id passed" if analysis_id.nil?
    raise "No datapoints file passed to new_analysis" if !options[:datapoint_file]
    raise "No datapoints_file exists #{options[:datapoint_file]}" if !File.exists?(options[:datapoint_file])

    dp_hash = JSON.parse(File.open(options[:datapoint_file]).read, :symbolize_names => true)

    if options[:reset_uuids]
      dp_hash[:analysis_uuid] = analysis_id
      dp_hash[:uuid] = UUID.new.generate
    end

    # merge in the analysis_id as it has to be what is in the database
    response = @conn.post do |req|
      req.url "analyses/#{analysis_id}/data_points.json"
      req.headers['Content-Type'] = 'application/json'
      req.body = dp_hash.to_json
    end

    if response.status == 201
      puts "new datapoints created for analysis #{analysis_id}"
    else
      raise "could not create new datapoints #{response.body}"
    end
  end

  def upload_datapoints(analysis_id, options)
    defaults = {}
    options = defaults.merge(options)

    raise "No analysis id passed" if analysis_id.nil?
    raise "No datapoints file passed to new_analysis" if !options[:datapoints_file]
    raise "No datapoints_file exists #{options[:datapoints_file]}" if !File.exists?(options[:datapoints_file])

    dp_hash = JSON.parse(File.open(options[:datapoints_file]).read, :symbolize_names => true)

    # merge in the analysis_id as it has to be what is in the database
    response = @conn.post do |req|
      req.url "analyses/#{analysis_id}/data_points/batch_upload.json"
      req.headers['Content-Type'] = 'application/json'
      req.body = dp_hash.to_json
    end

    if response.status == 201
      puts "new datapoints created for analysis #{analysis_id}"
    else
      raise "could not create new datapoints #{response.body}"
    end
  end

  def run_analysis(analysis_id, options)
    defaults = {analysis_action: "start", without_delay: false}
    options = defaults.merge(options)

    puts "Run analysis is configured with #{options.to_json}"
    response = @conn.post do |req|
      req.url "analyses/#{analysis_id}/action.json"
      req.headers['Content-Type'] = 'application/json'
      req.body = options.to_json
      req.options[:timeout] = 1800 #seconds
    end

    if response.status == 200
      puts "Recieved request to run analysis #{analysis_id}"
    else
      raise "Could not start the analysis"
    end
  end

  def kill_analysis(analysis_id)
    analysis_action = {analysis_action: "stop"}

    response = @conn.post do |req|
      req.url "analyses/#{analysis_id}/action.json"
      req.headers['Content-Type'] = 'application/json'
      req.body = analysis_action.to_json
    end

    if response.status == 200
      puts "Killed analysis #{analysis_id}"
    else
      raise "Could not kill the analysis with response of #{response.inspect}"
    end

  end

  def kill_all_analyses
    project_ids = get_project_ids
    puts "List of projects ids are: #{project_ids}"

    project_ids.each do |project_id|
      analysis_ids = get_analyses(project_id)
      puts analysis_ids
      analysis_ids.each do |analysis_id|
        puts "Trying to kill #{analysis_id}"
        kill_analysis(analysis_id)
      end
    end
  end


  def get_datapoint_status(analysis_id, filter = nil)
    # get the status of all the entire analysis
    if !analysis_id.nil?
      if filter.nil? || filter == ""
        resp = @conn.get "analyses/#{analysis_id}/status.json"
        puts "Data points (all): #{resp}"
      else
        resp = @conn.get "#{HOSTNAME}/analyses/#{analysis_id}/status.json", {jobs: filter}
        puts "Data points (#{filter}): #{resp}"
      end
    end
  end

end