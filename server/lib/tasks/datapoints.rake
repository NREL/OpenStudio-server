namespace :datapoints do
  desc 'download datapoints indefinitely'
  task :download => :environment do
    #puts "Analysis id is #{args.analysis_id}"
    # need to accept the UUID of the analysis ID
    still_downloading = true
    #analysis = Analysis.find(args.analysis_id)
    while still_downloading
      # Simple task to go through all the datapoints and download the results if they are complete
      puts "Checking for completed datapoints"
      begin
        ComputeNode.download_all_results
      rescue => e
        puts "Error during downloading of data points... will try to continue #{e.message}:#{e.backtrace.join("\n")}"
      end

      sleep 10
    end
  end
end
