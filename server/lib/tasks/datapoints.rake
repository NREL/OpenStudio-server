namespace :datapoints do
  desc 'download datapoints indefinitely'
  task :download, [:analysis_id] => :environment do |t, args|
    puts "Analysis id is #{args.analysis_id}"
    # need to accept the UUID of the analysis ID
    still_downloading = true
    analysis = Analysis.find(args.analysis_id)
    while still_downloading
      # Simple task to go through all the datapoints and download the results if they are complete
      if analysis
        puts "checking datapoints on #{analysis.id}"
        begin
          analysis.finalize_data_points
        rescue => e
          puts "Error during downloading of data points... will try to continue #{e.message}:#{e.backtrace.join("\n")}"
        end
      end
      sleep 5
    end
  end
end
