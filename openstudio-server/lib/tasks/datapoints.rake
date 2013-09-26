namespace :datapoints do
  desc 'download datapoints indefinitely'
  task :download, [:analysis_id] => :environment do |t, args|
    puts "Analysis id is #{args.analysis_id}"
    # need to accept the UUID of the analysis ID
    still_downloading = true
    analysis = Analysis.find(args.analysis_id)
    while still_downloading
      # Simple task to go through all the datapoints and download the results if they are complete
      if !analysis.nil?
        puts "checking datapoints on #{analysis.id}"
        analysis.download_data_from_workers
      end
      sleep(5)
    end
  end
end
