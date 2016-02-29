namespace :datapoints do
  desc 'download datapoints indefinitely'
  task download: :environment do
    # puts "Analysis id is #{args.analysis_id}"
    # need to accept the UUID of the analysis ID
    still_downloading = true
    # analysis = Analysis.find(args.analysis_id)
    while still_downloading
      # Simple task to go through all the datapoints and download the results if they are complete
      puts 'Checking for completed datapoints'
      begin
        ComputeNode.download_all_results
      rescue => e
        puts "Error during downloading of data points... will try to continue #{e.message}:#{e.backtrace.join("\n")}"
      end

      sleep 10
    end
  end

  desc 'test uploading a result_file'
  task test_file_upload: :environment do

    require 'faraday'
    @dp = DataPoint.first
    puts "DATAPOINT ID: #{@dp.id.to_s}"

    file = File.open("#{Rails.root}/lib/test.zip", 'rb')
    the_file = Base64.strict_encode64(file.read)
    file.close
    
    # file_data param
    file_data = {}
    file_data['display_name'] = 'This is the file display name'
    file_data['type'] = 'Results' # Results, Rdata, Reporting
    file_data['filename'] = 'test.zip'
    file_data['attachment'] = the_file

    json_request = JSON.generate('datapoint_id' => @dp.id.to_s, 'file' => file_data)
    #puts "POST http://<base_url>/data_points/:id/upload_file, parameters: #{json_request}"

    conn = Faraday.new(:url => 'http://localhost:3000') do |faraday|
      faraday.request  :url_encoded             # form-encode POST params
      faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end

    # post payload as JSON instead of "www-form-urlencoded" encoding:
    response = conn.post do |req|
      req.url "/data_points/#{@dp.id.to_s}/upload_file"
      req.headers['Content-Type'] = 'application/json'
      req.headers['Accept'] = 'application/json'
      req.body = json_request
    end

    puts response.body
  end
end
